package com.winlator.core;

import com.winlator.R;
import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.Map;

// Library R IDs are assigned by the host APK and cannot be Java case constants.
// The pinned upstream menu switches are mechanically converted to stable names.
public final class NexusResourceNames {
    private static final Map<Integer, String> NAMES = new HashMap<>();
    static {
        try {
            for (Field field : R.id.class.getFields()) NAMES.put(field.getInt(null), field.getName());
        } catch (IllegalAccessException error) { throw new ExceptionInInitializerError(error); }
    }
    public static String name(int id) { return NAMES.getOrDefault(id, ""); }
    private NexusResourceNames() {}
}
