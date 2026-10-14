.text
.global nexus_probe_entry
.type nexus_probe_entry, %function
nexus_probe_entry:
    mov x0, #1
    adr x1, probe_message
    mov x2, #14
    mov x8, #64
    svc #0
    mov x0, #0
    mov x8, #93
    svc #0
.size nexus_probe_entry, .-nexus_probe_entry
probe_message:
    .ascii "NEXUS_EXEC_OK\n"
.section .note.GNU-stack,"",%progbits
