import numpy as np

def normalize_pose(landmarks):
    """
    Converts raw MediaPipe landmarks into a normalized 1D vector.
    Centering: Uses hips as (0,0,0)
    Scaling: Uses shoulder distance as 1.0 unit
    """
    if not landmarks or len(landmarks) < 33:
        return None
    
    coords = np.array([[lm['x'], lm['y'], lm.get('z', 0)] for lm in landmarks])
    
    # Centering (Midpoint of Hips)
    hip_center = (coords[23] + coords[24]) / 2
    coords = coords - hip_center
    
    # Scaling (Shoulder distance)
    shoulder_dist = np.linalg.norm(coords[11] - coords[12])
    if shoulder_dist > 0:
        coords = coords / shoulder_dist
    else:
        return None
        
    return coords.flatten()
