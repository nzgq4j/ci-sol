import { cpSync, existsSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const sourceRoot = resolve(repositoryRoot, "src");
const targetRoot = resolve(repositoryRoot, "sharepoint", "sol-dms", "src", "solDmsApp");
const expectedParent = resolve(repositoryRoot, "sharepoint", "sol-dms", "src");

if (dirname(targetRoot) !== expectedParent || !targetRoot.endsWith(`${sep}solDmsApp`)) {
  throw new Error(`Refusing to synchronise to unexpected target: ${targetRoot}`);
}

if (!existsSync(resolve(repositoryRoot, "sharepoint", "sol-dms", "package.json"))) {
  throw new Error("The SPFx package has not been scaffolded.");
}

if (existsSync(targetRoot)) rmSync(targetRoot, { recursive: true, force: true });
mkdirSync(targetRoot, { recursive: true });

const includedDirectories = ["app", "components", "domain", "services", "styles"];
const excludedFiles = new Set(["services/runtime.ts", "services/demo.ts"]);

for (const directory of includedDirectories) {
  const source = join(sourceRoot, directory);
  const target = join(targetRoot, directory);
  cpSync(source, target, {
    recursive: true,
    filter(path) {
      const key = relative(sourceRoot, path).replaceAll("\\", "/");
      if (excludedFiles.has(key)) return false;
      return !key.endsWith(".test.ts") && !key.endsWith(".test.tsx");
    },
  });
}

const copied = readdirSync(targetRoot, { recursive: true }).length;
process.stdout.write(`Synchronised ${copied} SOL DMS application entries into the SPFx build tree.\n`);
