#!/bin/bash
echo "Installing Backstage dependencies..."


export VIRTUAL_ENV=$HOME/venv
python3 -m venv $VIRTUAL_ENV
export PATH="$VIRTUAL_ENV/bin:$PATH"
python3 -m pip install mkdocs-techdocs-core

yes "" | npx -y @backstage/create-app@latest

echo ""
echo "╔════════════════════════════════════════════════════════╗ "
echo "║  Setup Complete! Ready to launch Backstage!            ║ "
echo "╠════════════════════════════════════════════════════════╣ "
echo "║                                                        ║ "
echo "║  Open a new terminal and run:                          ║ "
echo "║                                                        ║ "
echo "║       yarn start                                         ║ "
echo "║                                                        ║ "
echo "║  Then access Backstage at:                             ║ "
echo "║                                                        ║ "
echo "║       http://localhost:3000                            ║ "
echo "║                                                        ║ "
echo "║  You might need to refresh the page once backend       ║ "
echo "║  is ready.                                             ║ "
echo "║                                                        ║ "
echo "║  Happy coding!                                         ║ "
echo "╚════════════════════════════════════════════════════════╝ "
echo ""
