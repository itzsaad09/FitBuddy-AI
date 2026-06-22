import pandas as pd
import numpy as np
from sklearn.neural_network import MLPClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import os

class PoseClassifier:
    """
    Artificial Neural Network (Multi-Layer Perceptron) Classifier that automatically trains on joined landmarks and labels from assets/.
    """
    def __init__(self, landmarks_path="assets/landmarks.csv", labels_path="assets/labels.csv"):
        self.model = MLPClassifier(
            hidden_layer_sizes=(64, 32),
            activation='relu',
            solver='adam',
            max_iter=500,
            random_state=42
        )
        self.is_trained = False
        
        # Check if pre-trained model exists to avoid CPU/RAM bottleneck on Render
        model_pickle_path = "assets/pose_model.pkl"
        alt_pickle_path = os.path.join("backend", model_pickle_path)
        
        loaded = False
        for path in [model_pickle_path, alt_pickle_path]:
            if os.path.exists(path):
                try:
                    import pickle
                    with open(path, 'rb') as f:
                        self.model = pickle.load(f)
                    self.is_trained = True
                    print(f"AI: [Success] Loaded pre-trained ANN from {path}!")
                    loaded = True
                    break
                except Exception as e:
                    print(f"AI: [Error] Failed to load pre-trained pickle: {e}")
                    
        if not loaded:
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
            print("AI: [Training] Starting training on assets data...")
            # 1. Load data
            df_landmarks = pd.read_csv(landmarks_path)
            df_labels = pd.read_csv(labels_path)
            
            # 2. Join on vid_id
            df = pd.merge(df_landmarks, df_labels, on='vid_id')
            
            # 3. Split by Video IDs to prevent data leakage (each video is either fully in train or fully in test)
            unique_vids = df['vid_id'].unique()
            vid_labels = df.groupby('vid_id')['class'].first()
            train_vids, test_vids = train_test_split(
                unique_vids, test_size=0.2, random_state=42, stratify=vid_labels
            )
            
            df_train = df[df['vid_id'].isin(train_vids)]
            df_test = df[df['vid_id'].isin(test_vids)]
            
            feature_cols = [col for col in df.columns if col not in ['vid_id', 'frame_order', 'class']]
            
            print(f"AI: [Normalize] Normalizing {len(df_train)} train and {len(df_test)} test samples...")
            
            def normalize_set(X_raw):
                X_normalized = []
                for row in X_raw:
                    landmarks_3d = row.reshape(-1, 3)
                    hip_center = (landmarks_3d[23] + landmarks_3d[24]) / 2
                    landmarks_centered = landmarks_3d - hip_center
                    shoulder_dist = np.linalg.norm(landmarks_centered[11] - landmarks_centered[12])
                    landmarks_scaled = landmarks_centered / shoulder_dist if shoulder_dist > 0 else landmarks_centered
                    X_normalized.append(landmarks_scaled.flatten())
                return np.array(X_normalized)
            
            X_train = normalize_set(df_train[feature_cols].values)
            y_train = df_train['class'].values
            
            X_test = normalize_set(df_test[feature_cols].values)
            y_test = df_test['class'].values
            
            # 4. Fit model on training videos
            print(f"AI: [Training] Fitting MLP model on {len(X_train)} train samples (from {len(train_vids)} videos)...")
            self.model.fit(X_train, y_train)
            self.is_trained = True
            
            # 5. Evaluate on test set (unseen videos)
            y_pred = self.model.predict(X_test)
            accuracy = accuracy_score(y_test, y_pred)
            print(f"AI: [Success] Neural Network (ANN) Brain Trained! {len(X_train)} samples train / {len(X_test)} samples test.")
            print(f"AI: Test Accuracy (Grouped by Video): {accuracy * 100:.2f}%")
            print("Classification Report:\n", classification_report(y_test, y_pred))
            
            # Save the trained model to pickle file so we don't have to retrain next time
            model_pickle_path = "backend/assets/pose_model.pkl" if "backend" not in os.getcwd() else "assets/pose_model.pkl"
            try:
                import pickle
                with open(model_pickle_path, 'wb') as f:
                    pickle.dump(self.model, f)
                print(f"AI: Saved trained model to {model_pickle_path}")
            except Exception as pickle_err:
                print(f"AI: [Warning] Could not save pickle: {pickle_err}")
                
        except Exception as e:
            print(f"AI: [Error] Training Error: {e}")

    def predict(self, normalized_vector):
        if not self.is_trained or normalized_vector is None:
            return "NO BRAIN"
        try:
            return str(self.model.predict([normalized_vector])[0])
        except:
            return "ERROR"

classifier = PoseClassifier()
