# r-pkg

This repository houses a devcontainer that setups an R package development environment. The container is setup to work with [GitHub Codespaces](https://github.com/features/codespaces) to instantly have a cloud-based developer workflow.

You can try out the Codespace by clicking on the following button:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/coatless-devcontainer/r-pkg?quickstart=1)

> [!NOTE]
>
> Codespaces are available to Students and Teachers for free [up to 180 core hours per month](https://docs.github.com/en/education/manage-coursework-with-github-classroom/integrate-github-classroom-with-an-ide/using-github-codespaces-with-github-classroom#about-github-codespaces)
> through [GitHub Education](https://education.github.com/). Otherwise, you will have 
> [up to 60 core hours and 15 GB free per month](https://github.com/features/codespaces#pricing).

Or, you can press the template button to create a new repository with the same setup so that you
can work locally on the devcontainer:

[![Use this template](https://img.shields.io/badge/Use%20this%20template-Create%20new%20repository-blue?logo=github)](https://github.com/coatless-devcontainer/r-pkg/generate)

This will create a fork of the repository that can be worked on inside a local copy of
[Visual Studio Code](https://code.visualstudio.com/) through the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers). With the extension installed, you can open the repository in a container by pressing `F1` (to bring up command palette) and typing `Dev Container: Reopen in Container`.

Lastly, you can directly obtain the underlying container image by typing in Terminal: 

```sh
docker pull ghcr.io/coatless-devcontainer/r-pkg:latest
```

## Quick start

Run the following series of commands inside of R once the container opens. Make sure to change `"name-of-package"` to your current package name.

```r
usethis::create_package("name-of-package")
usethis::use_package_doc()
usethis::use_agpl3_license()
usethis::use_testthat()
usethis::use_github_action("check-standard")
usethis::use_pkgdown_github_pages()
```

## Resources

- [Manual: Writing R extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html)
- [Textbook: R Packages](https://r-pkgs.org/)
- [usethis](https://usethis.r-lib.org/)
- [devtools](https://devtools.r-lib.org/)

## Developer notes

This repository uses a pre-built container strategy to have GitHub Actions build and, then, store the devcontainer in [GitHub's Container Repository](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry). 

We place the main logic of the devcontainer in [`.github/.devcontainer/devcontainer.json`](https://github.com/coatless-devcontainer/r-pkg/blob/main/.github/.devcontainer/devcontainer.json). From there, we use [`.github/workflows/pre-build-devcontainer.yml`](https://github.com/coatless-devcontainer/r-pkg/blob/main/.github/workflows/pre-build-devcontainer.yml) to build and publish the devcontainer onto GitHub's Container repository for the organization. Then, the repository's [`.devcontainer/devcontainer.json`](https://github.com/coatless-devcontainer/r-pkg/blob/main/.devcontainer/devcontainer.json) pulls the pre-built image.

> [!IMPORTANT]
>
> Make sure to specify the permissions as stated in the GitHub Actions workflow linked above
> and for organizations please make sure to have the organization's container registry enabled.
> 
> For more information, see [GitHub's Container Registry documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).