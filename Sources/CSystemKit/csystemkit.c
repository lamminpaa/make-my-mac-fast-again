#include "include/csystemkit.h"
#include <libproc.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>

// Returns 1 if the string looks like a version number (only digits and dots, e.g. "2.1.34")
static int is_version_string(const char *str) {
    if (!str || !*str) return 0;
    int has_dot = 0;
    int has_digit = 0;
    for (const char *p = str; *p; p++) {
        if (*p == '.') {
            has_dot = 1;
        } else if (isdigit((unsigned char)*p)) {
            has_digit = 1;
        } else {
            return 0;
        }
    }
    return has_dot && has_digit;
}

// Try to extract a meaningful name from a parent path component.
// Walks backwards from `end` (which points to the '/' before the version component)
// looking for a .app bundle name or the previous path component.
static const char *resolve_name_from_path(const char *path, const char *end) {
    if (end <= path) return NULL;

    // Walk back to find the start of the previous component
    const char *component_end = end; // points to '/'
    const char *p = component_end - 1;
    while (p > path && *p != '/') {
        p--;
    }
    const char *component_start = (*p == '/') ? p + 1 : p;
    size_t comp_len = (size_t)(component_end - component_start);

    if (comp_len == 0) return NULL;

    // Check if this component ends with ".app"
    if (comp_len > 4 && strncmp(component_end - 4, ".app", 4) == 0) {
        // Return pointer to the component start; caller must handle the .app stripping
        return component_start;
    }

    // If the component itself is also a version string, keep walking up
    // Make a temporary copy to check
    char tmp[256];
    if (comp_len >= sizeof(tmp)) return NULL;
    memcpy(tmp, component_start, comp_len);
    tmp[comp_len] = '\0';

    if (is_version_string(tmp)) {
        return resolve_name_from_path(path, component_start - 1);
    }

    return component_start;
}

int csk_get_process_info(pid_t pid, CSKProcessInfo *info) {
    if (!info) return -1;

    memset(info, 0, sizeof(CSKProcessInfo));
    info->pid = pid;

    // Get process name
    char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
    if (proc_pidpath(pid, pathbuf, sizeof(pathbuf)) > 0) {
        // Extract just the executable name from the path
        const char *last_slash = strrchr(pathbuf, '/');
        const char *name = last_slash ? last_slash + 1 : pathbuf;

        // If the name looks like a version number, try to get a better name from the path
        if (is_version_string(name) && last_slash) {
            const char *better = resolve_name_from_path(pathbuf, last_slash);
            if (better) {
                // Calculate the component length
                const char *comp_end = last_slash;
                // Find the end of this component (next '/')
                // better points to start of component, comp_end points to '/' after it
                // But we need to find where this component ends
                const char *ce = better;
                while (*ce && *ce != '/') ce++;
                size_t comp_len = (size_t)(ce - better);

                // Strip .app suffix if present
                if (comp_len > 4 && strncmp(ce - 4, ".app", 4) == 0) {
                    comp_len -= 4;
                }

                if (comp_len > 0 && comp_len < sizeof(info->name)) {
                    memcpy(info->name, better, comp_len);
                    info->name[comp_len] = '\0';
                } else {
                    strncpy(info->name, name, sizeof(info->name) - 1);
                }
            } else {
                strncpy(info->name, name, sizeof(info->name) - 1);
            }
        } else {
            strncpy(info->name, name, sizeof(info->name) - 1);
        }
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
