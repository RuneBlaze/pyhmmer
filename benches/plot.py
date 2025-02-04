import itertools
import json
import re
import math

import numpy
import matplotlib.pyplot as plt
from palettable.cartocolors.qualitative import Bold_3

plt.rcParams["svg.fonttype"] = "none"
# plt.xkcd(scale=0.5)

with open("benchmark.hmmsearch.json") as f:
    data = json.load(f)

CPU_RX = re.compile(r"(?:--cpu|--jobs) (\d+)")
for result in data["results"]:
    if result["command"].startswith(("hmmsearch", "hmmscan")):
        result["tool"] = result["command"].split(" ")[0]
    else:
        result["tool"] = "pyhmmer"
    if " Pfam.v33-1.hmm " in result["command"]:
        result["format"] = "text"
    elif " Pfam.v33-1.pressed.hmm.h3m " in result["command"]:
        result["format"] = "binary"
    elif " Pfam.v33-1.pressed.hmm " in result["command"]:
        result["format"] = "pressed"
    else:
        raise ValueError("could not find format")
    result["cpu"] = int(CPU_RX.search(result["command"]).group(1))

plt.figure(1, figsize=(12, 6))
plt.subplot(1, 2, 1)

data["results"].sort(key=lambda r: (r["tool"], r["format"], r["cpu"]))
for color, (tool, group) in zip(
    Bold_3.hex_colors, itertools.groupby(data["results"], key=lambda r: r["tool"])
):
    group = list(group)

    group_text = [r for r in group if r["format"] == "text"]
    if any(group_text):
        X = numpy.array([r["cpu"] for r in group_text])
        Y = numpy.array([r["mean"] for r in group_text])
        ci = [1.96 * r["stddev"] / math.sqrt(len(r["times"])) for r in group_text]
        plt.plot(X, Y, color=color, linestyle="--", marker="o")
        plt.fill_between(X, Y - ci, Y + ci, color=color, alpha=0.1)

    group_pressed = [r for r in group if r["format"] == "pressed"]
    if any(group_pressed):
        X = numpy.array([r["cpu"] for r in group_pressed])
        Y = numpy.array([r["mean"] for r in group_pressed])
        ci = [1.96 * r["stddev"] / math.sqrt(len(r["times"])) for r in group_pressed]
        plt.plot(X, Y, label=f"{tool}", color=color, marker="o")
        plt.fill_between(X, Y - ci, Y + ci, color=color, alpha=0.1)


plt.legend()
plt.xlabel("CPUs")
plt.ylabel("Time (s)")
# plt.savefig("benchmark.hmmsearch.svg")
# plt.show()


with open("benchmark.phmmer.json") as f:
    data = json.load(f)

CPU_RX = re.compile(r"(?:--cpu|--jobs) (\d+)")
for result in data["results"]:
    if result["command"].startswith("phmmer"):
        result["tool"] = result["command"].split(" ")[0]
    else:
        result["tool"] = "pyhmmer"
    result["cpu"] = int(CPU_RX.search(result["command"]).group(1))

# plt.figure(2, figsize=(6,6))
plt.subplot(1, 2, 2)
data["results"].sort(key=lambda r: (r["tool"], r["cpu"]))
for color, (tool, group) in zip(
    Bold_3.hex_colors[1:], itertools.groupby(data["results"], key=lambda r: r["tool"])
):
    group = list(group)
    X = numpy.array([r["cpu"] for r in group])
    Y = numpy.array([r["mean"] for r in group])
    ci = [1.96 * r["stddev"] / math.sqrt(len(r["times"])) for r in group]
    plt.plot(X, Y, label=f"{tool}", color=color, marker="o")
    plt.fill_between(X, Y - ci, Y + ci, color=color, alpha=0.1)

plt.legend()
plt.xlabel("CPUs")
plt.ylabel("Time (s)")
plt.savefig("benchmarks.svg", transparent=True)
plt.show()
