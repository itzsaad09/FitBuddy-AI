import os
import pandas as pd

class ExerciseDB:
    """
    Loads and indexes the main exercises.csv containing body parts, targets, and equipment.
    Used to dynamically map exercises selected on the frontend to the correct tracking joints.
    """
    def __init__(self, filepath="../assets/exercises.csv"):
        self.df = None
        self.filepath = filepath
        
        # Try loading from various relative locations
        paths_to_try = [
            filepath,
            os.path.join(os.path.dirname(__file__), "../../../assets/exercises.csv"),
            os.path.join("assets", "exercises.csv"),
            "exercises.csv"
        ]
        
        for path in paths_to_try:
            if os.path.exists(path):
                try:
                    self.df = pd.read_csv(path)
                    print(f"AI: 📚 ExerciseDB loaded successfully from {path} with {len(self.df)} exercises.")
                    break
                except Exception as e:
                    print(f"AI ERROR: Failed to load CSV from {path}: {e}")
        
        if self.df is None:
            print("AI WARNING: exercises.csv could not be found or loaded.")

    def lookup_exercise(self, name: str):
        """
        Looks up an exercise by name (case-insensitive, exact or partial match).
        """
        if self.df is None or not name:
            return None
            
        name_clean = name.strip().lower()
        # Try exact match first
        match = self.df[self.df['name'].str.lower() == name_clean]
        if not match.empty:
            return match.iloc[0].to_dict()
            
        # Try partial match (contains)
        match = self.df[self.df['name'].str.lower().str.contains(name_clean)]
        if not match.empty:
            return match.iloc[0].to_dict()
            
        return None

# Singleton instance
exercise_db = ExerciseDB()
