import json

with open("data/images.json") as f:
  images = json.loads(f.read())

board_names = []

for board_name, board in images.items():
  for image in reversed(board["images"]):
    major_ver = image["chrome_version"].split(".")[0]
    if not major_ver.isdigit():
      continue
    if image["channel"] != "stable-channel":
      continue
    if int(major_ver) > 124:
      continue
    board_names.append(board_name)
    break

print(len(board_names))
print(", ".join(board_names))