# AiBL Author Installs

This repository holds installation scripts for AiBL Author.

## Command Line Interafce (CLI) Installations

There are different commands to run depending on how you like to install CLI applications and which operating system that you are using.

### Easy Installation

In order to install the CLI execute the following command on Windows:

```sh
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/opmediainc/aibl-author-installs/master/cli/install.ps1" -OutFile "install-aibl.ps1"; powershell -ExecutionPolicy ByPass -c '.\install-aibl.ps1'; Remove-Item install-aibl.ps1
```

Or the following command for Mac and Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/opmediainc/aibl-author-installs/master/cli/install.sh | bash
```

### Advanced Instlation:

You can also clone this repository and install on your computer:

```sh
git clone https://github.com/OPMediaInc/aibl-author-installs.git
cd cli
```

Then execute the following command on windows:

```sh
powershell -ExecutionPolicy ByPass -c '.\install.ps1'
```

Or the following commands on Mac and Linux:

```sh
chmod +x ./install.sh
./install.sh
```

### Upgrading your CLI:

```sh
aibl upgrade
```

### Command Line Usage

There are many things that you can do with the AIBL Author CLI.

#### Manage context

You may need to authenticate to our generally available AIBL Author platform, or you may have an installation at work or even experimenting with your own private installation. AiBL Author CLI installs the "cloud" context by default.

Use the following command to list your current installed contexts:

```sh
aibl context list
```

If you need to re-add the "cloud" context, if you accidentally deleted it for example you may do so with:

```sh
aibl context add cloud https://demo.aiblx.ai/
```

If you are doing your own private installation you can add a local context by executing the following command, replacing the port number with the port number your installation is actually running on. You may need to replace the host name as well if your AiBL Author installation is running on a different computer:

```sh
aibl context add local http://localhost:3000/
```

You may switch context at any time by executing:

```sh
aibl context use local # or cloud or my-company, whichever context you added.
```

#### Authenticate

Switch to the context that you would like to authenticate agains using the `aibl context use` command, and then execute the following command:

```sh
aibl auth
```

After you execute this command you will be asked to sign in to a browser. Click the link from your terminal to go to the web page, and follow the login flow as directed. You will also be asked to confirm that you want to give the CLI access to your account. Confirm that you do in order to complete the authentication.

#### Verifying Your Identity

Once you have authenticated you can verify your status by executing the following command:

```sh
aibl whoami
```

You will also want to confirm the organizations and cores that you have access to by executing these commands:

```sh
aibl orgs list
aibl cores list
```

#### Discover More

To discover more of what you can do with the AiBL Author CLI execute `--help` after any command for more details.

```sh
aibl --help
```

## How the install works

The one-line install commands are designed to be the easiest option for most people. They download a small installer script for your operating system, validate the platform, and then set up the AiBL Author CLI in a way that is safe and predictable.

For novice users, the important thing to know is this:

- You do not need to manually install Node.js first.
- The installer will either use a compatible Node.js version already available on your machine or provision its own isolated runtime specifically for AiBL Author.
- It then installs the CLI package into that runtime and adds a lightweight wrapper command such as `aibl` to your shell environment.
- The result is a CLI that behaves like a regular command-line tool without requiring you to manage Node or global package conflicts yourself.

### Using an existing Node installation vs. a dedicated runtime

There are two common patterns:

1. Use the system or user-installed Node.js
   - If you already have a compatible Node version and are comfortable with Node tooling, you could install the CLI directly with npm.
   - This is a valid advanced option, but it is not the default workflow for the shortcut installers in this repository.

2. Use a dedicated AiBL runtime
   - The provided installers are intentionally self-contained.
   - They create a dedicated directory under your home folder, such as `~/.aibl/runtime/node` on macOS/Linux or `%USERPROFILE%\.aibl\runtime\node` on Windows.
   - That runtime contains a pinned Node.js version (for example, v22.14.0) that is used only for AiBL Author.
   - This avoids collisions with any other global Node.js versions already installed on the machine and helps keep CLI dependencies isolated.

This is especially useful in shared environments, developer machines with multiple toolchains, or situations where a global Node installation may be older or modified by other projects.

### What happens under the hood

When you run the installer, it typically does the following:

- Detects the OS and CPU architecture.
- Creates a dedicated AiBL home under your user profile.
- Downloads or verifies a Node.js runtime for that installation.
- Installs the `@op-media-inc/aibl-author-cli` package inside the isolated runtime.
- Creates wrapper launchers such as `aibl` in a local bin folder or user PATH.
- Optionally configures Claude Desktop integration if it is installed.

This makes the install more robust for non-technical users because it reduces the chance that a broken global Node setup, an outdated dependency, or a conflicting package version affects the AiBL CLI.

### Why this is helpful for beginners

The goal of the one-liner is to hide the complexity. You do not need to understand npm, PATH variables, shell configuration, or Node version management just to get started. The installer handles those details for you and leaves the CLI in a known-good state.

For more advanced users, the dedicated runtime offers predictability and isolation, which is often preferable to depending on whatever version of Node happens to be installed system-wide.