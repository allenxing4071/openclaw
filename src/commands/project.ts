import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";
import type { RuntimeEnv } from "../runtime.js";
import { defaultRuntime } from "../runtime.js";

const execFileAsync = promisify(execFile);

type ProjectCreateOptions = {
  dir?: string;
  name?: string;
  force?: boolean;
};

type ProjectDeployOptions = {
  dir?: string;
  composeFile?: string;
  build?: boolean;
  detach?: boolean;
};

type TemplateFile = {
  relPath: string;
  content: string;
  mode?: number;
};

const TEMPLATE_FILES: TemplateFile[] = [
  {
    relPath: "Dockerfile",
    content: [
      "FROM node:22-bookworm",
      "WORKDIR /app",
      "COPY . .",
      "RUN corepack enable",
      "ENV PORT=8080",
      'CMD ["bash", "-lc", "./scripts/start.sh"]',
      "",
    ].join("\n"),
  },
  {
    relPath: "docker-compose.yml",
    content: [
      "services:",
      "  app:",
      "    build: .",
      "    ports:",
      '      - "${PORT:-8080}:8080"',
      "    env_file:",
      "      - .env",
      "    restart: unless-stopped",
      "",
    ].join("\n"),
  },
  {
    relPath: "Makefile",
    content: [
      "install:",
      '\t@echo "Install deps in your app as needed"',
      "",
      "run:",
      "\t@./scripts/start.sh",
      "",
      "docker-build:",
      "\tdocker build -t app:local .",
      "",
      "docker-up:",
      "\tdocker compose up -d --build",
      "",
      "deploy: docker-up",
      "",
    ].join("\n"),
  },
  {
    relPath: ".env.example",
    content: ["PORT=8080", ""].join("\n"),
  },
  {
    relPath: "scripts/setup.sh",
    content: [
      "#!/usr/bin/env bash",
      "set -euo pipefail",
      "",
      "if [ ! -f .env ]; then",
      "  cp .env.example .env",
      '  echo "Created .env from .env.example"',
      "fi",
      "",
    ].join("\n"),
    mode: 0o755,
  },
  {
    relPath: "scripts/start.sh",
    content: [
      "#!/usr/bin/env bash",
      "set -euo pipefail",
      "",
      "if [ -f package.json ]; then",
      "  if [ -f pnpm-lock.yaml ]; then",
      "    corepack enable",
      "    pnpm install --frozen-lockfile || pnpm install",
      "    pnpm run start",
      "  else",
      "    npm install",
      "    npm run start",
      "  fi",
      "  exit 0",
      "fi",
      "",
      "if [ -f requirements.txt ]; then",
      "  python -m pip install -r requirements.txt",
      "  if [ -f main.py ]; then",
      "    python main.py",
      "    exit 0",
      "  fi",
      "fi",
      "",
      'echo "No known entrypoint found. Please edit scripts/start.sh"',
      "exit 1",
      "",
    ].join("\n"),
    mode: 0o755,
  },
];

function resolveProjectDir(opts: ProjectCreateOptions | ProjectDeployOptions): string {
  const baseDir = opts.dir?.trim();
  const name = "name" in opts ? opts.name?.trim() : undefined;
  if (baseDir) {
    return path.resolve(baseDir);
  }
  if (name) {
    return path.resolve(process.cwd(), name);
  }
  return path.resolve(process.cwd());
}

async function fileExists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function writeTemplateFile(
  rootDir: string,
  template: TemplateFile,
  force: boolean,
): Promise<{ wrote: boolean; path: string }> {
  const fullPath = path.join(rootDir, template.relPath);
  const exists = await fileExists(fullPath);
  if (exists && !force) {
    return { wrote: false, path: fullPath };
  }
  await fs.mkdir(path.dirname(fullPath), { recursive: true });
  await fs.writeFile(fullPath, template.content, "utf-8");
  if (template.mode) {
    await fs.chmod(fullPath, template.mode);
  }
  return { wrote: true, path: fullPath };
}

export async function projectCreateCommand(
  opts: ProjectCreateOptions,
  runtime: RuntimeEnv = defaultRuntime,
) {
  const rootDir = resolveProjectDir(opts);
  const force = Boolean(opts.force);
  await fs.mkdir(rootDir, { recursive: true });

  const results = [];
  for (const template of TEMPLATE_FILES) {
    results.push(await writeTemplateFile(rootDir, template, force));
  }

  const wrote = results.filter((r) => r.wrote).map((r) => r.path);
  const skipped = results.filter((r) => !r.wrote).map((r) => r.path);

  if (wrote.length === 0) {
    runtime.log("Project template already exists. Use --force to overwrite.");
  } else {
    runtime.log(`Project template created in: ${rootDir}`);
  }
  if (skipped.length > 0) {
    runtime.log(`Skipped existing files:\n- ${skipped.join("\n- ")}`);
  }
}

export async function projectDeployCommand(
  opts: ProjectDeployOptions,
  runtime: RuntimeEnv = defaultRuntime,
) {
  const rootDir = resolveProjectDir(opts);
  const composeFile = path.resolve(rootDir, opts.composeFile ?? "docker-compose.yml");
  const build = opts.build !== false;
  const detach = opts.detach !== false;

  if (!(await fileExists(composeFile))) {
    runtime.error(`Missing compose file: ${composeFile}`);
    runtime.exit(1);
    return;
  }

  const args = ["compose", "-f", composeFile, "up"];
  if (detach) {
    args.push("-d");
  }
  if (build) {
    args.push("--build");
  }

  try {
    const dockerPath = process.env.OPENCLAW_DOCKER_PATH || "/usr/bin/docker";
    try {
      await execFileAsync(dockerPath, args, { cwd: rootDir });
    } catch (err) {
      if (dockerPath !== "docker") {
        await execFileAsync("docker", args, { cwd: rootDir });
      } else {
        throw err;
      }
    }
    runtime.log("Deploy completed.");
  } catch (err) {
    runtime.error(`Deploy failed: ${err instanceof Error ? err.message : String(err)}`);
    runtime.exit(1);
  }
}
