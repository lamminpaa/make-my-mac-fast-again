#ifndef CSYSTEMKIT_H
#define CSYSTEMKIT_H

#include <sys/types.h>
#include <stdint.h>

typedef struct {
    pid_t pid;
    pid_t ppid;
    uid_t uid;
    char name[256];
    int status;
    /// Unix epoch seconds when the process was started (kp_proc.p_starttime).
    /// Zero if unavailable.
    int64_t start_time_seconds;
} CSKProcessInfo;

typedef struct {
    uint64_t resident_size;
    uint64_t virtual_size;
    double cpu_usage;
} CSKProcessResourceUsage;

/// Get basic info for a single process by PID
int csk_get_process_info(pid_t pid, CSKProcessInfo *info);

/// Get resource usage (memory, CPU) for a single process
int csk_get_process_resource_usage(pid_t pid, CSKProcessResourceUsage *usage);

/// Get list of all PIDs. Returns count, fills pids array up to max_count.
int csk_get_all_pids(pid_t *pids, int max_count);

/// Read the NUL-joined argv for a process via KERN_PROCARGS2.
/// Writes up to `max_len - 1` bytes into `buf`, always NUL-terminated.
/// Separator bytes between arguments are replaced with ASCII 0x1F (unit separator)
/// so callers can split without losing NULs in the buffer.
/// Returns the number of argv entries joined (>= 0) on success, or a negative errno on failure.
int csk_get_process_args(pid_t pid, char *buf, int max_len);

#endif /* CSYSTEMKIT_H */
