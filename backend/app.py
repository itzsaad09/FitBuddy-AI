import os
from app import create_app

app = create_app()

if __name__ == '__main__':
    # Render injects PORT; fall back to 5000 for local dev
    port = int(os.environ.get('PORT', 5000))
    # debug=False in production; use FLASK_DEBUG env var locally if needed
    debug = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug)
