import os

def create_project_structure():
    # Define the structure: keys are directories, values are lists of files
    structure = {
        "lib": ["main.dart"],
        "lib/database": ["database_helper.dart"],
        "lib/models": ["note.dart"],
        "lib/screens": ["home_screen.dart", "note_detail_screen.dart", "search_screen.dart"],
        "lib/widgets": ["note_card.dart", "color_picker_dialog.dart", "empty_state.dart"],
        "lib/utils": ["constants.dart"],
    }

    for folder, files in structure.items():
        # Create the directory if it doesn't exist
        os.makedirs(folder, exist_ok=True)
        
        for file in files:
            file_path = os.path.join(folder, file)
            # Create an empty file (using 'w' mode)
            with open(file_path, 'w') as f:
                pass 
            print(f"Created: {file_path}")

    print("\n✅ Project structure created successfully!")

if __name__ == "__main__":
    create_project_structure()