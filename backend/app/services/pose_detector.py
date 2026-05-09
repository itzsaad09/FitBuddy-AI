import cv2
import numpy as np

_pose_model = None

def get_pose_model():
    global _pose_model
    if _pose_model is None:
        try:
            from mediapipe.solutions import pose as mp_pose
            _pose_model = mp_pose.Pose(
                static_image_mode=True, 
                model_complexity=1,
                min_detection_confidence=0.3,
                min_tracking_confidence=0.3
            )
            print("MediaPipe Pose (Static + coordinate-fix) initialized.")
        except Exception as e:
            print(f"FAILED to initialize MediaPipe: {e}")
    return _pose_model

def get_pose_landmarks(image):
    try:
        pose = get_pose_model()
        if pose is None or image is None:
            return []

        # Try 1: Original
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = pose.process(rgb)
        rotation = 0

        # Try 2: Rotate if failed
        if not results.pose_landmarks:
            rotated = cv2.rotate(image, cv2.ROTATE_90_CLOCKWISE)
            rgb = cv2.cvtColor(rotated, cv2.COLOR_BGR2RGB)
            results = pose.process(rgb)
            rotation = 90
            
        if not results.pose_landmarks:
            rotated = cv2.rotate(image, cv2.ROTATE_90_COUNTERCLOCKWISE)
            rgb = cv2.cvtColor(rotated, cv2.COLOR_BGR2RGB)
            results = pose.process(rgb)
            rotation = 270

        landmarks = []
        if results.pose_landmarks:
            for lm in results.pose_landmarks.landmark:
                x, y = lm.x, lm.y
                
                # ROTATE COORDINATES BACK TO MATCH PHONE SCREEN
                if rotation == 90:
                    final_x = y
                    final_y = 1 - x
                elif rotation == 270:
                    final_x = 1 - y
                    final_y = x
                else:
                    final_x = x
                    final_y = y

                landmarks.append({
                    'x': final_x,
                    'y': final_y,
                    'z': lm.z,
                    'visibility': lm.visibility
                })
            print(f"DEBUG: Found pose with rotation {rotation}")
        return landmarks
    except Exception as e:
        print(f"DEBUG ERROR: {e}")
        return []
