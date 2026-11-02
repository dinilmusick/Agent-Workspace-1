import { mkdir, readFile, writeFile } from "node:fs/promises";

await mkdir("dist", { recursive: true });
const html = await readFile(new URL("./index.html", import.meta.url), "utf8");
await writeFile("dist/index.html", html);
