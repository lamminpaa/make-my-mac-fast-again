#include "include/csystemkit.h"
#include <libproc.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>

int csk_get_process_info(pid_t pid, CSKProcessInfo *info) {
    if (!info) return -1;

    memset(info, 0, sizeof(CSKProcessInfo));
    info->pid = pid;

    // Get process name
    char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
    if (proc_pidpath(pid, pathbuf, sizeof(pathbuf)) > 0) {
        // Extract just the executable name from the path
        const char *name = strrchr(pathbuf, '/');
        if (name) {
            name++; // skip the slash
        } else {
            name = pathbuf;
        }
        strncpy(info->name, name, sizeof(info->name) - 1);
    } else {
        // Fallback: try proc_name
        proc_name(pid, info->name, sizeof(info->name));
    }

    // Get ppid and uid via sysctl
    struct kinfo_proc kp;
    size_t len = sizeof(kp);
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid };

    if (sysctl(mib, 4, &kp, &len, NULL, 0) == 0 && len > 0) {
        info->ppid = kp.kp_eproc.e_ppid;
        info->uid = kp.kp_eproc.e_ucred.cr_uid;
        info->status = kp.kp_proc.p_stat;
    }

    return 0;
}

int csk_get_process_resource_usage(pid_t pid, CSKProcessResourceUsage *usage) {
    if (!usage) return -1;

    memset(usage, 0, sizeof(CSKProcessResourceUsage));

    struct proc_taskinfo taskinfo;
    int size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskinfo, sizeof(taskinfo));

    if (size != sizeof(taskinfo)) {
        return -1;
    }

    usage->resident_size = taskinfo.pti_resident_size;
    usage->virtual_size = taskinfo.pti_virtual_size;

    // CPU usage: total time in nanoseconds
    // We report total user+system time; the caller can compute percentage over intervals
    double total_time_ns = (double)(taskinfo.pti_total_user + taskinfo.pti_total_system);
    usage->cpu_usage = total_time_ns;

    return 0;
}

int csk_get_all_pids(pid_t *pids, int max_count) {
    if (!pids || max_count <= 0) return -1;

    int count = proc_listallpids(NULL, 0);
    if (count <= 0) return -1;

    pid_t *all_pids = (pid_t *)malloc(sizeof(pid_t) * count);
    if (!all_pids) return -1;

    count = proc_listallpids(all_pids, sizeof(pid_t) * count);
    if (count <= 0) {
        free(all_pids);
        return -1;
    }

    int result = count < max_count ? count : max_count;
    memcpy(pids, all_pids, sizeof(pid_t) * result);
    free(all_pids);

    return result;
}
