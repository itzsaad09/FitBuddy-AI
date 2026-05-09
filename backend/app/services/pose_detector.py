import cv2

_pose_model = None

def get_pose_model():
    global _pose_model
    if _pose_model is None:
        try:
            from mediapipe.solutions import pose as mp_pose
            _pose_model = mp_pose.Pose(
                static_image_mode=False,
                min_detection_confidence=0.5,
                min_tracking_confidence=0.5
            )
            print("MediaPipe Pose model initialized successfully.")
        except Exception as e:
            print(f"FAILED to initialize MediaPipe: {e}")
    return _pose_model

def get_pose_landmarks(image):
    try:
        pose = get_pose_model()
        if pose is None:
            return []
            
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = pose.process(rgb_image)

        landmarks = []
        if results.pose_landmarks:
            print(f"Pose detected! Found {len(results.pose_landmarks.landmark)} landmarks.")
            for lm in results.pose_landmarks.landmark:
                landmarks.append({
                    'x': lm.x,
                    'y': lm.y,
                    'z': lm.z,
                    'visibility': lm.visibility
                })
        else:
            print("No pose detected in frame.")
            
        return landmarks
    except Exception as e:
        print(f"Error in pose detection: {e}")
        return []
