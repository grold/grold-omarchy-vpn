#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <unistd.h>
#include <sys/types.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: grold-omarchy-vpn-run [--bypass] <command> [args...]\n"
                  << "Runs the specified command inside the VPN or Bypass split-tunnel routing cgroup.\n";
        return 1;
    }

    bool bypass = false;
    int cmdIdx = 1;
    if (std::string(argv[1]) == "--bypass") {
        bypass = true;
        cmdIdx = 2;
        if (argc < 3) {
            std::cerr << "Error: No command specified after --bypass\n";
            return 1;
        }
    }

    std::string cgroupPath = bypass ? "/sys/fs/cgroup/grold_vpn_bypass/cgroup.procs"
                                    : "/sys/fs/cgroup/grold_vpn/cgroup.procs";

    pid_t pid = getpid();
    std::ofstream cgroupFile(cgroupPath);
    if (cgroupFile.is_open()) {
        cgroupFile << pid << "\n";
        cgroupFile.close();
    } else {
        std::cerr << "Warning: Could not add PID to " << cgroupPath << " (check permissions)\n";
    }

    // Execute target command
    std::vector<char*> args;
    for (int i = cmdIdx; i < argc; ++i) {
        args.push_back(argv[i]);
    }
    args.push_back(nullptr);

    execvp(args[0], args.data());
    perror("execvp failed");
    return 1;
}
