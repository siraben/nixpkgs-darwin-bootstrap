#!/usr/bin/env python3
import os
from pathlib import Path


path = Path(os.environ["out"]) / "lib/mes/__assert_fail.c"
text = path.read_text()
text = text.replace(
    "  if (file && *file)\n    {\n      eputs (file);\n      eputs (\":\");\n    }\n",
    "  if (file)\n    if (*file)\n      {\n        eputs (file);\n        eputs (\":\");\n      }\n",
)
text = text.replace(
    "  if (function && *function)\n    {\n      eputs (function);\n      eputs (\":\");\n    }\n",
    "  if (function)\n    if (*function)\n      {\n        eputs (function);\n        eputs (\":\");\n      }\n",
)
path.write_text(text)
