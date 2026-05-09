from flask import Blueprint, request, jsonify
import cv2
import numpy as np
from .services.pose_detector import process_pose_image

main_bp = Blueprint('main', __name__)

@main_bp.route('/', methods=['GET'])
def health_check():
    return jsonify({'status': 'ok', 'message': 'FitBuddy AI backend is running'}), 200

@main_bp.route('/detect', methods=['POST'])
def detect_pose():
    try:
        file = request.files.get('image')
        if not file:
            return jsonify({'error': 'No image provided'}), 400

        np_img = np.frombuffer(file.read(), np.uint8)
        image = cv2.imdecode(np_img, cv2.IMREAD_COLOR)
        
        # Get base64 image from Python AI
        base64_image = process_pose_image(image)

        if base64_image:
            return jsonify({'image': base64_image})
        else:
            return jsonify({'error': 'Processing failed'}), 500
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500
