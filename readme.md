# unity tum main campus



## Prerequistes
- Sumo 1.21 (or later, important traci must be the same version)
- Windows 10/11
- Python 3.11 
- Git Bash
- Unity 2022.3.8f1 

## Automatic installation

Clone the repo:
```
git clone https://github.com/TUM-VT/Sumonity-UnityBaseProject.git
```

Execute the install script in Powershell as Admin:

```
cd .\Sumonity-UnityBaseProject\
.\setup.ps1
```


Then get the 3d model from tum2twin:
```

powershell -ExecutionPolicy Bypass -File download_unity_fbx.ps1
```

## Manual installation



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

download the 3d model:
```
wget "https://gitlab.lrz.de/tum-gis/tum2twin-datasets/-/raw/0ec6f8d87cfe58ac03bdae2c690632c08fd3d625/fbx/tum_main_campus.fbx" -OutFile "Assets/3d_model/tum_main_campus.fbx"
```



### Sumo Python Envrionment Setup

The prompts in this guide refer to git bash and not "powershell" or "cmd"

Go to The Sumo Folder where the python script for "TraCI" is located:

Setup the envrionment
```
cd Assets/Sumonity/SumoTraCI
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

Note: 
- Use Python 3.11, otherwise you will run into compatability issues.


## Running the Simulation

Open the project in Unity and run the scene "Main Campus"

## Troubleshooting

### VCS Tool and Win11
If you have to work with Windows 11, install vcstool2 in a python venv!
