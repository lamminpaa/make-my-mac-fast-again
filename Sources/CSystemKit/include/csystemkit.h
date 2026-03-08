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

#endif /* CSYSTEMKIT_H */
