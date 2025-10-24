# Systemd Unicorn Setup Scripts

Systemd service setup automation scripts for Unicorn-based Rails applications.

## Overview

This repository contains generator scripts that create `systemd_setup.sh` files for projects. These setup scripts automate the deployment and configuration of systemd services for Unicorn application servers.

**🎯 Universal Tool**: This tool is **completely generic** and can be used with **any** Unicorn Rails project.

## Quick Links

- **汎用的な使い方 (Generic Usage)**: [README.generic.md](README.generic.md) - どんなプロジェクトでも使える方法
- **日本語ドキュメント**: [README.ja.md](README.ja.md) - 詳細な日本語ドキュメント
- **Multiple Projects Management**: See below for managing multiple projects

## Repository Structure

```
systemd-unicorn-setup/
├── config/
│   ├── projects.yml                       # Multiple projects configuration
│   ├── projects.example.yml               # Example configuration
│   └── .systemd-setup.example.yml         # Single project template
├── templates/
│   └── systemd_setup.sh.template          # Universal script template
├── scripts/
│   ├── generate_setup.sh                  # 🌟 Universal generator (Recommended)
│   ├── generate_from_yaml.sh              # YAML-based multi-project generator
│   ├── generate_all.sh                    # Legacy generator
│   ├── generate_setup_scripts.sh          # Legacy generator
│   └── lib/
│       ├── yaml_parser.sh                 # YAML parser library
│       ├── ssh_parser.sh                  # SSH config parser library
│       └── single_project_parser.sh       # Single project parser
├── README.md                               # This file
├── README.generic.md                       # 🌟 Generic usage guide
└── README.ja.md                            # Japanese documentation
```

## Managed Projects

The following projects are managed by these scripts:

| Project | Service Name | App Path | Server |
|---------|-------------|----------|---------|
| medica | medica-unicorn | /home/deploy/apps/medica | 45.77.21.63:11270 |
| corp | corp-unicorn | /home/deploy/apps/corp | 45.77.178.149:11270 |
| ex_dance_stadium | dance-stadium-unicorn | /home/deploy/apps/dance_stadium | 108.61.162.167:57777 |
| ndp-kabarai-lp-for-fujii | kabarai-for-fujii-unicorn | /home/deploy/apps/kabarai_for_fujii | 202.182.99.237:11270 |
| ndp_yamikin_lp | ndp-yamikin-lp-unicorn | /home/deploy/apps/ndp_yamikin_lp | 104.156.239.46:11270 |
| ndp-seramid | ndp-seramid-unicorn | /home/deploy/apps/ndp-seramid | 104.238.151.79:11270 |
| ndp-king-gear | king-gear-unicorn | /home/deploy/apps/king_gear | 45.32.28.159:57777 |

## Quick Start

### For Any Project (Universal Mode) 🌟

**See [README.generic.md](README.generic.md) for detailed generic usage guide.**

```bash
# Interactive mode (easiest)
./scripts/generate_setup.sh --interactive

# Command-line mode
./scripts/generate_setup.sh \
  --service-name my-app-unicorn \
  --app-name my_app \
  --app-path /home/deploy/apps/my_app \
  --ssh-host my_app_prod \
  --output /path/to/project/script/systemd_setup.sh

# Project directory mode (with .systemd-setup.yml)
./scripts/generate_setup.sh --project /path/to/project
```

### For Multiple Projects Management

```bash
# List all managed projects
./scripts/generate_from_yaml.sh --list

# Validate configuration
./scripts/generate_from_yaml.sh --validate

# Generate all projects
./scripts/generate_from_yaml.sh

# Generate specific project only
./scripts/generate_from_yaml.sh medica
```

## YAML-Based Generator (Recommended)

### Features

- **YAML Configuration File**: Centralized project management in `config/projects.yml`
- **SSH Config Integration**: Automatically retrieves HostName/Port from `~/.ssh/config`
- **Directory Mapping**: Explicit local-to-remote path mappings
- **Validation**: Pre-deployment validation of configuration and SSH connectivity
- **Selective Generation**: Generate all projects or specific projects only

### Usage

#### List Projects

```bash
./scripts/generate_from_yaml.sh --list
```

#### Validate Configuration

```bash
./scripts/generate_from_yaml.sh --validate
```

Validates:
- SSH Host exists in `~/.ssh/config`
- SSH connection info (HostName, Port, User) retrieval
- Local directory existence

#### Generate Scripts

```bash
# All projects
./scripts/generate_from_yaml.sh

# Specific project
./scripts/generate_from_yaml.sh medica
```

### Adding New Projects

1. Add new project entry to `config/projects.yml`
2. Ensure SSH Host is configured in `~/.ssh/config`
3. Validate: `./scripts/generate_from_yaml.sh --validate`
4. Generate: `./scripts/generate_from_yaml.sh <project_name>`

See `README.ja.md` for detailed YAML configuration format.

## Legacy Generators

For backward compatibility, legacy generator scripts are still available:

### `generate_all.sh`

Generates setup scripts directly without requiring a template file.

**Usage:**
```bash
./scripts/generate_all.sh
```

### `generate_setup_scripts.sh`

Template-based generator that uses the medica project's setup script as a template.

**Usage:**
```bash
./scripts/generate_setup_scripts.sh
```

**Note:** For new projects, use the **YAML-based generator** (`generate_from_yaml.sh`) instead

## Generated Setup Script Features

Each generated `systemd_setup.sh` includes:

### Execution Modes

1. **Full Setup (Default)**
   ```bash
   ./script/systemd_setup.sh
   ```
   - Transfers service file
   - Enables auto-start
   - Configures systemd

2. **Validation Mode**
   ```bash
   ./script/systemd_setup.sh --validate
   ```
   - Zero-downtime validation
   - Tests environment without affecting running processes
   - Validates service file syntax
   - Checks paths and dependencies
   - Runs test service to verify configuration

3. **Test Mode**
   ```bash
   ./script/systemd_setup.sh --test-only
   ```
   - Transfers and validates service file
   - Does NOT enable auto-start
   - Safe for testing

4. **Dry Run**
   ```bash
   ./script/systemd_setup.sh --dry-run
   ```
   - Shows what would be deployed
   - No changes made

### Validation Checks

The `--validate` mode performs comprehensive checks:

1. **Existing Process Detection**
   - Identifies running unicorn processes
   - No impact on existing services

2. **Environment Testing**
   - Verifies Ruby environment
   - Tests Bundle configuration
   - Validates Unicorn gem availability
   - Uses temporary test service

3. **Syntax Validation**
   - systemd service file syntax check
   - Configuration verification
   - Uses systemd-analyze

4. **Path Verification**
   - Application path existence
   - Gemfile presence
   - unicorn.rb configuration file

5. **Dependency Checks**
   - MySQL/MariaDB status
   - Nginx status

6. **Summary Report**
   - Complete validation results
   - Next step recommendations

### SSH Configuration

Scripts automatically detect SSH hosts from `~/.ssh/config` based on IP and port.

**Requirements:**
- SSH config must contain Host entries with matching HostName and Port
- SSH key-based authentication configured
- User has sudo privileges on remote server

### Service File Requirements

Each project requires a systemd service file at:
```
<project_path>/config/systemd/<service-name>.service
```

**Example service file structure:**
```ini
[Unit]
Description=App Unicorn Server
After=network.target mysql.service

[Service]
Type=forking
User=deploy
Group=deploy
WorkingDirectory=/home/deploy/apps/app/current

Environment=RAILS_ENV=production
Environment=BUNDLE_GEMFILE=/home/deploy/apps/app/current/Gemfile
Environment=RBENV_ROOT=/home/deploy/.rbenv
Environment=PATH=/home/deploy/.rbenv/shims:/home/deploy/.rbenv/bin:/usr/local/bin:/usr/bin:/bin

ExecStart=/bin/bash -lc 'bundle exec unicorn -c config/unicorn.rb -E production -D'
ExecReload=/bin/kill -USR2 $MAINPID
ExecStop=/bin/kill -QUIT $MAINPID

PIDFile=/home/deploy/apps/app/shared/tmp/pids/unicorn.pid

Restart=on-failure
RestartSec=10
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
```

## Workflow Example

### Complete Deployment

```bash
# 1. Generate setup scripts for all projects
cd /path/to/systemd-unicorn-setup/scripts
./generate_all.sh

# 2. Navigate to project
cd /Users/akimitsukoshikawa/workspace/torcheees/medica

# 3. Validate configuration (no downtime)
./script/systemd_setup.sh --validate

# 4. Deploy service configuration
./script/systemd_setup.sh

# 5. Verify deployment
ssh medica-server 'sudo systemctl status medica-unicorn'
```

### Safe Testing Workflow

```bash
# 1. Test with dry run
./script/systemd_setup.sh --dry-run

# 2. Deploy in test mode (no auto-start)
./script/systemd_setup.sh --test-only

# 3. Manual verification
ssh server 'sudo systemctl cat service-name'

# 4. If OK, enable production setup
./script/systemd_setup.sh
```

## Adding New Projects

To add a new project to the generator:

1. Edit both generator scripts (`generate_all.sh` and `generate_setup_scripts.sh`)

2. Add project entry to the PROJECTS array:
   ```bash
   declare -a PROJECTS=(
     # existing entries...
     "project_dir|app_name|service-name|/remote/path|ip:port|/local/path"
   )
   ```

3. Add generation call in `generate_all.sh`:
   ```bash
   echo "生成中: project_name"
   generate_script "service-name" "app_name" "/remote/path" "ip:port" "/local/path/script/systemd_setup.sh"
   ```

4. Regenerate all scripts:
   ```bash
   ./scripts/generate_all.sh
   ```

## Troubleshooting

### SSH Connection Failed

**Problem:** `SSH接続失敗: hostname`

**Solutions:**
- Verify `~/.ssh/config` has correct Host entry
- Test SSH manually: `ssh hostname`
- Check SSH key authentication
- Verify IP and port match config

### Service File Not Found

**Problem:** `サービスファイルが見つかりません`

**Solutions:**
- Ensure service file exists at `config/systemd/<service-name>.service`
- Check file path in script matches actual location
- Verify file permissions

### Validation Failures

**Problem:** Environment tests fail in `--validate` mode

**Solutions:**
- Check Ruby environment on server
- Verify rbenv installation
- Ensure Gemfile exists in application directory
- Check bundle installation
- Review logs: `sudo journalctl -u <service-name>-test -n 50`

### Permission Denied

**Problem:** Cannot write to `/etc/systemd/system/`

**Solutions:**
- Verify user has sudo privileges
- Check sudoers configuration
- Ensure SSH user is in correct group

## Systemd Service Management

After deployment, manage services with:

```bash
# Check status
ssh server 'sudo systemctl status service-name'

# Start service
ssh server 'sudo systemctl start service-name'

# Stop service
ssh server 'sudo systemctl stop service-name'

# Restart service
ssh server 'sudo systemctl restart service-name'

# Reload configuration
ssh server 'sudo systemctl reload service-name'

# View logs
ssh server 'sudo journalctl -u service-name -f'

# Enable auto-start
ssh server 'sudo systemctl enable service-name'

# Disable auto-start
ssh server 'sudo systemctl disable service-name'
```

## Best Practices

1. **Always validate first**
   - Run `--validate` before production deployment
   - Verify all checks pass

2. **Test mode for new configurations**
   - Use `--test-only` for initial deployment
   - Verify manually before enabling auto-start

3. **Keep backups**
   - Backup existing service files before updates
   - Maintain version control of service configurations

4. **Monitor logs**
   - Check journalctl after deployment
   - Verify no errors in startup

5. **Gradual rollout**
   - Deploy to one server first
   - Verify stability before rolling out to all servers

## Security Considerations

- Service files contain sensitive paths and configurations
- Ensure proper file permissions (644 for service files)
- Restrict sudo access appropriately
- Use SSH key authentication only
- Review service file contents before deployment

## License

Internal use only.

## Support

For issues or questions:
- Check troubleshooting section
- Review systemd logs: `journalctl -u service-name`
- Validate SSH configuration
- Verify service file syntax

## Related Documentation

- [Systemd Service Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Unicorn Configuration](https://bogomips.org/unicorn/)
- [Rails Production Deployment](https://guides.rubyonrails.org/deployment.html)
