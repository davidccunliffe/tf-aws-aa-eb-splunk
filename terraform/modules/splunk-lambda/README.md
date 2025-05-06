cd modules/splunk-lambda/src
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt -t .python
rm -rf venv
rm -f build.zip
zip -r9 build.zip handler.py .python
deactivate
rm -rf .python
cd ../../..
terraform apply --auto-approve