import os

# Get the current directory
current_dir = os.getcwd()

# Define the path to the "Assets" folder
assets_dir = os.path.join(current_dir, "Assets")

# Traverse through the child folders inside the "Assets" folder
for dir in os.listdir(assets_dir):
    child_dir = os.path.join(assets_dir, dir)
    if os.path.isdir(child_dir):
        # Change the current working directory to the child folder
        os.chdir(child_dir)

        # Run git status
        git_status_output = os.popen("git status").read()

        # Check if the output contains "working tree clean"
        if "working tree clean" not in git_status_output:
            print(f"----------> {child_dir} ----------> check!")
        else:
            print(f"{child_dir} clean!")

        # Change the current working directory back to the original directory
        os.chdir(current_dir)