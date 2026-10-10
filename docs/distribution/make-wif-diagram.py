"""Render the WIF OIDC-exchange diagram as a LinkedIn-friendly PNG.

Usage: python docs/distribution/make-wif-diagram.py
Output: docs/distribution/wif-oidc-diagram.png (1600x900)
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
from pathlib import Path

W, H = 1600, 900
BG = "#F6F8FA"
INK = "#1F2328"
MUTED = "#57606E"
ACCENT = "#1A73E8"
GREEN = "#1A7F37"
BOX = "#FFFFFF"
BORDER = "#D0D7DE"

fig, ax = plt.subplots(figsize=(W / 100, H / 100), dpi=100)
fig.patch.set_facecolor(BG)
ax.set_facecolor(BG)
ax.set_xlim(0, W)
ax.set_ylim(0, H)
ax.axis("off")

# Title
ax.text(W / 2, H - 60, "Keyless GitHub Actions \u2192 GCP via Workload Identity Federation",
        ha="center", va="center", fontsize=30, weight="bold", color=INK)
ax.text(W / 2, H - 100, "short-lived OIDC tokens in, impersonated service account out \u2014 no keys anywhere",
        ha="center", va="center", fontsize=17, color=MUTED)

# Actor columns
actors = [("GitHub Actions", 0.16), ("Google STS", 0.50), ("GCP APIs", 0.84)]
ax_x = {}
for label, fx in actors:
    x = fx * W
    ax_x[label] = x
    box = FancyBboxPatch((x - 150, H - 230), 300, 70,
                         boxstyle="round,pad=8", facecolor=BOX, edgecolor=BORDER, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, H - 195, label, ha="center", va="center", fontsize=20, weight="bold", color=INK)
    ax.plot([x, x], [H - 230, 190], color="#C0C7CE", linewidth=1.5, linestyle=(0, (4, 3)))

GH, STS, GCP = (ax_x["GitHub Actions"], ax_x["Google STS"], ax_x["GCP APIs"])


def arrow(x1, y1, x2, y2, color=ACCENT, style="-", width=2.2):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle="-|>", color=color, linewidth=width,
                                linestyle=style, shrinkA=4, shrinkB=4))


def label(x, y, text, color=INK, size=16, weight="normal", bg="#E8F1FD"):
    ax.text(x, y, text, ha="center", va="center", fontsize=size, weight=weight,
            color=color, bbox=dict(boxstyle="round,pad=5", facecolor=bg,
                                   edgecolor="none"))


# 1. mint OIDC (self)
y = H - 300
ax.plot([GH, GH + 130], [y, y], color=ACCENT, linewidth=2.2)
ax.annotate("", xy=(GH + 6, y - 2), xytext=(GH + 130, y - 2),
            arrowprops=dict(arrowstyle="-|>", color=ACCENT, linewidth=2.2))
label(GH + 65, y + 34, "1  Mint OIDC token")
label(GH + 65, y - 34, "iss: token.actions.githubusercontent.com", size=12.5, color=MUTED, bg="#EFF2F5")

# 2. exchange
y = H - 430
arrow(GH, y, STS, y)
label((GH + STS) / 2, y + 32, "2  Exchange OIDC for federated token")

# 3. validate (self on STS)
arrow(STS, y - 96, STS + 150, y - 96)
ax.annotate("", xy=(STS + 6, y - 98), xytext=(STS + 150, y - 98),
            arrowprops=dict(arrowstyle="-|>", color=ACCENT, linewidth=2.2))
label(STS + 75, y - 62, "3  Validate issuer, audience, condition")
label(STS + 75, y - 128, "attribute.repository == OWNER/REPO", size=12.5, color=MUTED, bg="#EFF2F5")

# 4. short-lived token back
y = H - 590
arrow(STS, y, GH, y, color=GREEN)
label((GH + STS) / 2, y + 32, "4  Short-lived access token (~1h)", color=GREEN, bg="#EAF7EE")

# 5. call APIs
y = H - 700
arrow(GH, y, GCP, y)
label((GH + GCP) / 2, y + 34, "5  Call APIs as the impersonated service account")

# Footer
ax.text(W / 2, 92, "No service-account keys \u2022 attribute-scoped trust \u2022 proof tier 2: applied live",
        ha="center", va="center", fontsize=16, weight="bold", color=INK)
ax.text(W / 2, 56, "gcp-architect-blog.web.app",
        ha="center", va="center", fontsize=14, color=MUTED)

out = Path(__file__).resolve().parent / "wif-oidc-diagram.png"
fig.savefig(out, facecolor=BG, bbox_inches="tight", pad_inches=0.25)
print(f"wrote {out} ({out.stat().st_size // 1024} KB)")
