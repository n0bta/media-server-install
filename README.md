# Media Server Install

This script automates the installation of Jellyfin on a Debian-based Linux server, including necessary Docker services for optimal media server functionality.

## Prerequisites

* Debian-based server (e.g., Ubuntu)
* git installed
* Static IP address configured
* Docker requirements met
* Root access

## Installation

```bash
git clone https://github.com/n0bta/media-server-install.git
cd media-server-install
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
