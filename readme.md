# unity tum main campus

this is the base project for our unity simulations

The setup was done accoroding to https://unityatscale.com/unity-version-control-guide/how-to-setup-unity-project-on-github/

## Prerequistes
- Sumo 1.18 (or later, important traci must be the same version)
- Windows 10 (Do no use Windows 11)
- Python 3.11 (or later)
- Git Bash
- Unity 2022.3.8f1 (only this version is tested, other version might create errors)


## installation

### Repo Setup

Make sure to have the ssh key of this machine your are working on added to your account.

Use Git Bash for the setup of the repo, otherwise vcs tools will not work

install vcs tools:
```
pip install vcstool2
```

IMPORTANT: Check for warnings regarding the PATH variable. 

get submodules
```
vcs import < assets.repos

```


### Sumo Python Envrionment Setup

The prompts in this guide refer to git bash and not "powershell" or "cmd"

Go to The Sumo Folder where the python script for "TraCI" is located:

Setup the envrionment
```
cd Assets/Sumonity/Sumo
```

Install the virtualenvironment toolset
```
pip install virtualenv 
```

Enable execution of scripts, open powershell in admin mode:
```
Set-ExecutionPolicy Unrestricted
```


Activate it and install dependencies:
```
python3.11 -m venv venv
.\venv\scripts\activate
pip install -r requirements.txt

```

Note: Use Python 3.11, otherwise you will run into compatability issues.


Note: 
If you run into issues, try to do this part in powershell


## Troubleshooting

### VCS Tool and Win11
If you have to work with Windows 11, install vcstool2 in a python venv!