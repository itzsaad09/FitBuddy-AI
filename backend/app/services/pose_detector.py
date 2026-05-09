import cv2
import base64
import numpy as np

_pose_model = None

def get_pose_model():
    global _pose_model
    if _pose_model is None:
        try:
            from mediapipe.solutions import pose as mp_pose
            _pose_model = mp_pose.Pose(
                static_image_mode=False, # Optimized for video/real-time
                model_complexity=0,
                min_detection_confidence=0.5,
                min_tracking_confidence=0.5
            )
            print("MediaPipe Pose (VIDEO MODE) initialized.")
        except Exception as e:
            print(f"CRITICAL ERROR: {e}")
    return _pose_model

def process_pose_image(image):
    """
    Detects pose, draws skeleton on the image, and returns base64 string.
    """
    try:
        from mediapipe.solutions import pose as mp_pose
        from mediapipe.solutions import drawing_utils as mp_drawing
        
        pose = get_pose_model()
        if pose is None or image is None:
            return None

        # Process image
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = pose.process(rgb)

        # Draw skeleton if found
        if results.pose_landmarks:
            mp_drawing.draw_landmarks(
                image, 
                results.pose_landmarks, 
                mp_pose.POSE_CONNECTIONS,
                mp_drawing.DrawingSpec(color=(0, 255, 0), thickness=2, circle_radius=2),
                mp_drawing.DrawingSpec(color=(0, 0, 255), thickness=2, circle_radius=1)
            )

        # Encode back to base64
        _, buffer = cv2.imencode('.jpg', image, [int(cv2.IMWRITE_JPEG_QUALITY), 70])
        base64_str = base64.b64encode(buffer).decode('utf-8')
        
        return base64_str
    except Exception as e:
        print(f"Error: {e}")
        return None
