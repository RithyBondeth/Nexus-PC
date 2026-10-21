package com.winlator.core;

import android.content.Context;
import android.system.Os;
import com.winlator.xenvironment.RootFS;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.InputStream;
import java.nio.file.Files;
import java.security.MessageDigest;

/** Pinned native ELF mappings are installed from the APK, never downloaded. */
public final class NexusPackagedRuntime {
    private NexusPackagedRuntime() {}
    private static byte[] readBytes(InputStream input) throws java.io.IOException {
        java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int count;
        while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
        return output.toByteArray();
    }
    public static void install(Context context) {
        try {
            File root = RootFS.find(context).getRootDir().getCanonicalFile();
            File nativeDir = new File(context.getApplicationInfo().nativeLibraryDir).getCanonicalFile();
            StringBuilder json = new StringBuilder();
            try (java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.InputStreamReader(
                    context.getAssets().open("nexus-native-map.json"), java.nio.charset.StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) json.append(line);
            }
            JSONArray entries = new JSONArray(json.toString());
            // Upgrade only the three APK-pinned Wine files, preserving rootfs,
            // legacy prefixes and saves. Run before creating a new prefix so its
            // system DLL copies agree with the Unix dispatcher slot.
            String guestJson;
            try (InputStream input = context.getAssets().open("nexus-guest-map.json")) {
                guestJson = new String(readBytes(input), java.nio.charset.StandardCharsets.UTF_8);
            }
            JSONArray guests = new JSONArray(guestJson);
            for (int i = 0; i < guests.length(); i++) {
                JSONObject entry = guests.getJSONObject(i);
                File target = new File(root, entry.getString("path"));
                if (!target.getCanonicalPath().startsWith(root.getPath() + "/opt/wine/lib/wine/"))
                    throw new IllegalStateException("Invalid packaged Wine entry");
                byte[] data;
                try (InputStream input = context.getAssets().open(entry.getString("asset"))) {
                    data = readBytes(input);
                }
                byte[] expected = MessageDigest.getInstance("SHA-256").digest(data);
                StringBuilder guestDigest = new StringBuilder();
                for (byte b : expected) guestDigest.append(String.format("%02x", b & 255));
                if (!guestDigest.toString().equals(entry.getString("sha256")))
                    throw new IllegalStateException("Packaged Wine checksum mismatch");
                if (target.isFile() && MessageDigest.isEqual(expected,
                        MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(target.toPath())))) continue;
                File staging = new File(target.getParentFile(), target.getName() + ".nexus-update");
                Files.write(staging.toPath(), data);
                Files.move(staging.toPath(), target.toPath(),
                        java.nio.file.StandardCopyOption.REPLACE_EXISTING,
                        java.nio.file.StandardCopyOption.ATOMIC_MOVE);
            }
            byte[] buffer = new byte[128 * 1024];
            for (int i = 0; i < entries.length(); i++) {
                JSONObject entry = entries.getJSONObject(i);
                File file = new File(root, entry.getString("path"));
                File binary = new File(nativeDir, entry.getString("library"));
                if (!file.getParentFile().getCanonicalPath().startsWith(root.getPath() + "/") ||
                    !binary.getCanonicalFile().getParentFile().equals(nativeDir) || !binary.isFile())
                    throw new IllegalStateException("Invalid packaged runtime entry");
                MessageDigest hash = MessageDigest.getInstance("SHA-256");
                try (InputStream input = new java.io.FileInputStream(binary)) {
                    int n;
                    while ((n = input.read(buffer)) != -1) hash.update(buffer, 0, n);
                }
                StringBuilder digest = new StringBuilder();
                for (byte b : hash.digest()) digest.append(String.format("%02x", b & 255));
                if (!digest.toString().equals(entry.getString("sha256")))
                    throw new IllegalStateException("Packaged runtime checksum mismatch");
                Files.deleteIfExists(file.toPath());
                Os.symlink(binary.getPath(), file.getPath());
            }
        } catch (Exception error) {
            throw new IllegalStateException("Could not install pinned native runtime", error);
        }
    }
}
