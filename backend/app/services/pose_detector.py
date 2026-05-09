import cv2
import numpy as np

# Global model variable
_pose_model = None

def get_pose_model():
    global _pose_model
    if _pose_model is None:
        try:
            # Lazy import to avoid startup conflicts
            import mediapipe as mp
            mp_pose = mp.solutions.pose
            
            # static_image_mode=True is REQUIRED for individual frames
            _pose_model = mp_pose.Pose(
                static_image_mode=True, 
                model_complexity=0,
                min_detection_confidence=0.3,
                min_tracking_confidence=0.3
            )
            print("AI: Pose model initialized (JSON Mode)")
        except Exception as e:
            print(f"AI ERROR: {e}")
    return _pose_model

def process_pose_image(image):
    """
    Processes an image and returns ONLY the landmark coordinates.
    """
    try:
        pose = get_pose_model()
        if pose is None or image is None:
            return None

        # MediaPipe requires RGB
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = pose.process(rgb_image)

        # Extract landmark data
        landmarks_data = []
        if results.pose_landmarks:
            for lm in results.pose_landmarks.landmark:
                landmarks_data.append({
                    'x': float(lm.x),
                    'y': float(lm.y),
                    'v': float(lm.visibility)
                })
        
        return landmarks_data
        
    except Exception as e:
        print(f"AI ERROR: {e}")
        return None
