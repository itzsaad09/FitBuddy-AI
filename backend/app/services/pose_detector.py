import cv2

_pose_model = None

def get_pose_model():
    global _pose_model
    if _pose_model is None:
        try:
            from mediapipe.solutions import pose as mp_pose
            # Changed static_image_mode to True for individual frame processing
            # Lowered detection confidence to 0.3 to be more sensitive
            _pose_model = mp_pose.Pose(
                static_image_mode=True, 
                min_detection_confidence=0.3,
                min_tracking_confidence=0.3
            )
            print("MediaPipe Pose model (STATIC MODE) initialized.")
        except Exception as e:
            print(f"FAILED to initialize MediaPipe: {e}")
    return _pose_model

def get_pose_landmarks(image):
    try:
        pose = get_pose_model()
        if pose is None:
            return []
            
        # Convert BGR to RGB
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = pose.process(rgb_image)

        landmarks = []
        if results.pose_landmarks:
            print(f"DEBUG BACKEND: Pose detected! Landmarks: {len(results.pose_landmarks.landmark)}")
            for lm in results.pose_landmarks.landmark:
                landmarks.append({
                    'x': lm.x,
                    'y': lm.y,
                    'z': lm.z,
                    'visibility': lm.visibility
                })
        else:
            print("DEBUG BACKEND: No pose detected in this image.")
            
        return landmarks
    except Exception as e:
        print(f"DEBUG BACKEND ERROR: {e}")
        return []
