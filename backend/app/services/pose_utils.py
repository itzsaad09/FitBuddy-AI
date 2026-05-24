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

def calculate_angle(a, b, c):
    """
    Calculates the 3D angle (in degrees) at joint B, between vectors BA and BC.
    a, b, c are dictionaries with keys 'x', 'y', 'z'.
    """
    try:
        a_coords = np.array([a['x'], a['y'], a.get('z', 0)])
        b_coords = np.array([b['x'], b['y'], b.get('z', 0)])
        c_coords = np.array([c['x'], c['y'], c.get('z', 0)])
        
        ba = a_coords - b_coords
        bc = c_coords - b_coords
        
        dot_product = np.dot(ba, bc)
        norm_ba = np.linalg.norm(ba)
        norm_bc = np.linalg.norm(bc)
        
        if norm_ba == 0 or norm_bc == 0:
            return 0.0
            
        cosine_angle = dot_product / (norm_ba * norm_bc)
        cosine_angle = np.clip(cosine_angle, -1.0, 1.0)
        
        angle_rad = np.arccos(cosine_angle)
        return float(np.degrees(angle_rad))
    except Exception as e:
        print(f"Error calculating angle: {e}")
        return 0.0

