# Media Server Install

This script automates the installation of Jellyfin on a Debian-based Linux server, including necessary Docker services for optimal media server functionality.

## Prerequisites

* Debian-based server (e.g., Ubuntu)
* curl installed
* Static IP address configured
* Docker requirements met
* Root access

## Installation
```bash
curl -fsSL https://github.com/n0bta/media-server-install/raw/refs/heads/main/msi.sh > /tmp/msi.sh && sudo bash /tmp/msi.sh && rm /tmp/msi.sh
```

## Manual Installation

1. Download msi.sh (curl, git, or manually copy to the server)
2. Execute the script as root
```bash
sudo bash msi.sh
```

## License

This project is licensed under The Unlicense license.

## Contributing

Contributions are welcome to this project. Please submit a pull request to the repository.

## Additional Notes

* This script is designed to be run on a clean server.
* It is recommended to back up your server before running this script.
* After the script completes, you can access your Jellyfin server at http://<server_ip>:8096.

Please let me know if you have any other questions.
