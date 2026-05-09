from flask import Blueprint, request, jsonify
import cv2
import numpy as np
from .services.pose_detector import process_pose_image

main_bp = Blueprint('main', __name__)

@main_bp.route('/', methods=['GET'])
def health_check():
    return jsonify({'status': 'online'}), 200

@main_bp.route('/detect', methods=['POST'])
def detect_pose():
    try:
        file = request.files.get('image')
        if not file:
            return jsonify({'error': 'No image provided'}), 400

        np_img = np.frombuffer(file.read(), np.uint8)
        image = cv2.imdecode(np_img, cv2.IMREAD_COLOR)
        
        if image is None:
            return jsonify({'error': 'Invalid image'}), 400

        # Return a list of coordinates
        landmarks = process_pose_image(image)

        return jsonify({
            'landmarks': landmarks if landmarks else []
        })
            
    except Exception as e:
        print(f"Backend Error: {e}")
        return jsonify({'error': 'Internal server error'}), 500
