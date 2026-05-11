import pandas as pd
import numpy as np
from sklearn.neighbors import KNeighborsClassifier
import os

class PoseClassifier:
    """
    KNN Classifier that automatically trains on joined landmarks and labels from assets/.
    """
    def __init__(self, landmarks_path="assets/landmarks.csv", labels_path="assets/labels.csv"):
        self.model = KNeighborsClassifier(n_neighbors=5, weights='distance')
        self.is_trained = False
        
        # Check relative to backend/
        if os.path.exists(landmarks_path) and os.path.exists(labels_path):
            self.train(landmarks_path, labels_path)
        else:
            # Fallback for different CWDs
            alt_landmarks = os.path.join("backend", landmarks_path)
            alt_labels = os.path.join("backend", labels_path)
            if os.path.exists(alt_landmarks) and os.path.exists(alt_labels):
                self.train(alt_landmarks, alt_labels)

    def train(self, landmarks_path, labels_path):
        try:
            print("AI: 🧠 Starting training on assets data...")
            # 1. Load data
            df_landmarks = pd.read_csv(landmarks_path)
            df_labels = pd.read_csv(labels_path)
            
            # 2. Join on vid_id
            df = pd.merge(df_landmarks, df_labels, on='vid_id')
            
            # 3. Extract features (exclude metadata columns)
            # MediaPipe landmarks start after vid_id and frame_order
            # Columns are x_nose, y_nose, z_nose, x_left_eye_inner...
            feature_cols = [col for col in df.columns if col not in ['vid_id', 'frame_order', 'class']]
            X_raw = df[feature_cols].values
            y = df['class'].values
            
            print(f"AI: 📏 Normalizing {len(X_raw)} training samples...")
            X_normalized = []
            for row in X_raw:
                # Reshape row to (33, 3) for normalization
                landmarks_3d = row.reshape(-1, 3)
                
                # Centering (Hips are landmarks 23 and 24)
                hip_center = (landmarks_3d[23] + landmarks_3d[24]) / 2
                landmarks_centered = landmarks_3d - hip_center
                
                # Scaling (Shoulders are 11 and 12)
                shoulder_dist = np.linalg.norm(landmarks_centered[11] - landmarks_centered[12])
                if shoulder_dist > 0:
                    landmarks_scaled = landmarks_centered / shoulder_dist
                else:
                    landmarks_scaled = landmarks_centered
                    
                X_normalized.append(landmarks_scaled.flatten())
            
            # 4. Train
            self.model.fit(X_normalized, y)
            self.is_trained = True
            print(f"AI: ✅ KNN Brain Trained & Normalized! {len(df)} frames indexed.")
        except Exception as e:
            print(f"AI: ❌ Training Error: {e}")

    def predict(self, normalized_vector):
        if not self.is_trained or normalized_vector is None:
            return "NO BRAIN"
        try:
            return str(self.model.predict([normalized_vector])[0])
        except:
            return "ERROR"

classifier = PoseClassifier()
