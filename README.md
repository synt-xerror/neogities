# Neogities — a "neocities-ruby" fork by SyntaxError!
Original repo: [neocities-ruby](https://github.com/neocities/neocities-ruby)

## What's the big deal?
Neogities was created to fix some issues in the original application and add extra features, turning it into a full toolbox for Neocities developers.

It's called "Neogities" because it works similarly to Git (naming is not my strongest skill).

This project is actively being developed and will be updated soon.

---

## Future Features
- Support for `.neoignore` to exclude files from deployment (can also use `.gitignore` if desired)
- Automatic detection and removal of deleted files from remote
- Ability to push specific files without uploading the entire directory
- And more… suggestions and contributions are welcome!

---

## Getting Started

> ⚠️ **Warning:** This application is under construction! Some errors may occur, and certain features may not be fully implemented yet.

### Fast Installation (Linux)
<details>
  <summary>Click to expand Linux instructions</summary>

Run this command to install Neogities quickly:

```bash
curl -sSL https://raw.githubusercontent.com/synt-xerror/neogities/main/install/install.sh | bash
```

Or, if you want to inspect the script first:

```bash
curl -O https://raw.githubusercontent.com/synt-xerror/neogities/main/install/install.sh
less install.sh   # inspect the script
bash install.sh   # run it
```

**Pre-requisites**

Make sure your system is up to date:

```bash
sudo apt update && sudo apt upgrade
```

- Install required packages:

```bash
sudo apt install git ruby bundler
```

- Ensure your PATH includes ~/.local/bin:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```
Adjust the shell file if you use zsh or others.

- Check Ruby version (needs 3.4.0 or newer):

```bash
ruby -v
```

- Test Bundler separately:

```bash
gem install bundler
bundle -v
```

**Important Notes**

Run the script as a normal user, not root. Using sudo can cause `$HOME` conflicts and permission issues.