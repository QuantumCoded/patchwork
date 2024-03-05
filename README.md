<a name="readme-top"></a>

<br />
<div align="center">
  <h3 align="center">Patchwork</h3>

  <p align="center">
    Selective declaration of mutable files.
  </p>
</div>

<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#with-flakes">With Flakes</a></li>
        <li><a href="#without-flakes">Without Flakes</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
  </ol>
</details>

## About The Project

The current methods to declaratively manage arbitrary files in NixOS and home-manager generally follow one of two approaches:
The `home.file` approach, where the file is generated, placed on the `/nix/store`, and symbolically linked into place;
and the `systemd.tmpfiles` approach, where a file is generated or copied, placed on the `/nix/store`, and copied into place.
However, I was not satisfied with the result of either approach when configuring applications that store dynamic information in config files.

Here's why:
- Symbolic links to the `/nix/store` prevent these applications from storing important operating data in their config files.
- When replacing the file with systemd tmpfiles, config is managed only on activation, meaning changes do not take effect until `nixos-rebuild switch` or `home-manager switch` are ran.
- When copying the file with systemd tmpfiles, config is initialized only once, not managed continually, leading to config that diverges from the declared state.

Patchwork aims to address some of these annoyances by providing a new config declaration method for applications that require only some of their config to be declared.
Patchwork should be used only when other methods such as `home.file` and `systemd.tmpfiles` do not provide the desired result.

Patchwork accomplishes partial file declaration using RegEx patches to ensure fixed config. These RegEx(s) are applied on activation similar to `systmd.tmpfiles`,
but also optionally provides a service to monitor declared files and re-apply patches on modification.

> [!CAUTION]
> Patches specified in Patchwork must be idempotent! This means that applying the patch once is functionally identical to applying the patch multiple times.
> Patches that are not idempotent *WILL* cause corruption of your config files.
 
## Getting Started

### With Flakes

#### Using NixOS

<details>
<summary><i>Click to Expand</i></summary>
  
```nix
{
  inputs.patchwork.url = "github:quantumcoded/patchwork";

  outputs = { self, nixpkgs, patchwork }: {
    # change `yourhostname` to your actual hostname
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        patchwork.nixosModules.default

        # or for home-manager in NixOS
        {
          home-manager.sharedModules = [
            patchwork.homeModules.default
          ];
        }
      ];
    };
  };
}
```
</details>

#### Using home-manager standalone

<details>
<summary><i>Click to Expand</i></summary>

```nix
{
  inputs.patchwork.url = "github:quantumcoded/patchwork";

  outputs = { self, nixpkgs, patchwork }: {
    # change `yourusername` and `yourhostname` to your actual username and hostname
    homeConfigurations."yourusername@yourhostname" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        patchwork.homeModules.default
      ];
    };
  };
}
```
</details>

### Without Flakes

#### Using NixOS

<details>
<summary><i>Click to Expand</i></summary>
Add the following to your NixOS configuration:

```nix
{
  imports = [ "${builtins.fetchTarball "https://github.com/quantumcoded/patchwork/archive/main.tar.gz"}/nixos.nix" ];
}
```

or with pinning:

```nix
{
  imports = let
    # replace this with an actual commit id or tag
    commit = "";
  in [
    "${builtins.fetchTarball {
      url = "https://github.com/quantumcoded/patchwork/archive/${commit}.tar.gz";
      # update hash from nix build output
      sha256 = "";
    }}/nixos.nix"
  ];
}
```
</details>

#### Using home-manager standalone

<details>
<summary><i>Click to Expand</i></summary>
Add the following to your home-manager configuration:

```nix
{
  imports = [ "${builtins.fetchTarball "https://github.com/quantumcoded/patchwork/archive/main.tar.gz"}/home.nix" ];
}
```

or with pinning:

```nix
{
  imports = let
    # replace this with an actual commit id or tag
    commit = "";
  in [
    "${builtins.fetchTarball {
      url = "https://github.com/quantumcoded/patchwork/archive/${commit}.tar.gz";
      # update hash from nix build output
      sha256 = "";
    }}/home.nix"
  ];
}
```
</details>

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

Imagine a simple music player application with the following config file:

```ini
[Cache]
LastVolume=10
LastSong="My Song"

[Settings]
MusicDirectory=/home/user/music
```

Trying to manage this config file using `home.file` will prevent the caching of songs and volume,
and trying to mange the file with `systmd.tmpfiles` will allow the user to change the music directory,
creating impurity.

This is where Patchwork comes in.

Patchwork can declare a patch for the MusicDirectory line like so:

```nix
{
  services.patchwork = {
    enable = true;

    # use the watcher service (default: false)
    # without this, patches are only run on activation
    watchForModify = true;

    # backup config files (default: true)
    backup = true;

    # the file extension to use for backups (default: "bak")
    backupExtension = "bak";

    # an attribute set of file and patches to apply
    # in NixOS the path must be absolute, in home-manager the path is relative to `~`
    # the value can be a string for a single patch or a list of strings for multiple
    # if no patches are specified, Patchwork is effectively disabled
    patches = {
      ".config/music-player/config.conf" = "s/MusicDirectory=.*/MusicDirectory=\/home\/user\/music/";
    };
  };
}
```

In the event of changes to the MusicDirectory, whether initiated by the music player or through other means,
Patchwork ensures that the MusicDirectory maintains its declared state, while still permitting the program to utilize its cache settings.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## License

Distributed under the MIT License. See `LICENSE` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>
