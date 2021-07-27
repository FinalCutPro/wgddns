import os
import json
import requests

with open("config.json", mode="r")as config_file:
    config = json.load(config_file)
dns = config["dns"]
domain = config["domain"]

headers = {
    'accept': 'application/dns-json',
}

params = (
    ('name', domain),
    ('type', 'A'),
)

response = requests.get(dns, headers=headers, params=params)
response = json.loads(response.text)
answer = response["Answer"]
for answer in answer:
    if answer["type"] == 1:
        ip = answer["data"]

try:
    with open("last_ip.txt", "r")as file:
        last_ip = file.read()
        if ip != last_ip:
            os.system("sudo systemctl restart wg-quick@wg0")
except FileNotFoundError:
    with open("last_ip.txt", "w")as file:
        file.write(ip)
    with open("last_ip.txt", "r")as file:
        last_ip = file.read()
        if ip != last_ip:
            os.system("sudo systemctl restart wg-quick@wg0")