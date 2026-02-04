import path from "node:path";
import type { CommandHandler } from "./commands-types.js";
import { projectDeployCommand } from "../../commands/project.js";
import { logVerbose } from "../../globals.js";

const PROJECT_ALIASES = new Map<string, string>([
  ["ai-account-automation", "ai-account-automation"],
  ["ai account automation", "ai-account-automation"],
  ["ai账户自动化", "ai-account-automation"],
  ["账号自动化", "ai-account-automation"],
]);

function normalizeBody(text: string | undefined): string {
  return (text ?? "").trim().toLowerCase();
}

function resolveProjectName(body: string): string | null {
  for (const [alias, name] of PROJECT_ALIASES.entries()) {
    if (body.includes(alias)) {
      return name;
    }
  }
  return null;
}

function detectDeployIntent(body: string): boolean {
  return (
    body.includes("deploy") ||
    body.includes("部署") ||
    body.includes("上线") ||
    body.includes("发布")
  );
}

function detectConfirm(body: string): boolean {
  return body.includes("确认") || body.includes("confirm");
}

function detectProd(body: string): boolean {
  return body.includes("prod") || body.includes("生产");
}

function buildRuntimeCollector() {
  const logs: string[] = [];
  const errors: string[] = [];
  return {
    logs,
    errors,
    runtime: {
      log: (message: string) => logs.push(message),
      error: (message: string) => errors.push(message),
      exit: (code: number) => {
        throw new Error(errors[0] ?? `Deploy failed (exit ${code})`);
      },
    },
  };
}

export const handleDeployCommand: CommandHandler = async (params, allowTextCommands) => {
  if (!allowTextCommands) {
    return null;
  }
  if (!params.command.isAuthorizedSender) {
    return null;
  }

  const body = normalizeBody(params.command.rawBodyNormalized);
  if (!detectDeployIntent(body)) {
    return null;
  }

  const projectName = resolveProjectName(body);
  if (!projectName) {
    return {
      shouldContinue: false,
      reply: {
        text: "⚠️ 未识别项目名称。请用：部署 ai-account-automation（或 /deploy ai-account-automation）。",
      },
    };
  }

  if (!detectConfirm(body)) {
    return {
      shouldContinue: false,
      reply: { text: `准备部署 ${projectName}。请回复：确认 部署 ${projectName}` },
    };
  }

  const workspaceRoot =
    params.cfg.agents?.defaults?.workspace?.trim() || params.workspaceDir || process.cwd();
  const projectDir = path.resolve(workspaceRoot, projectName);
  const composeFile = detectProd(body) ? "docker-compose.prod.yml" : "docker-compose.yml";

  try {
    const collector = buildRuntimeCollector();
    await projectDeployCommand(
      { dir: projectDir, composeFile, build: true, detach: true },
      collector.runtime,
    );
    return {
      shouldContinue: false,
      reply: { text: `✅ 已触发部署：${projectName}（${composeFile}）` },
    };
  } catch (err) {
    logVerbose(`deploy failed: ${String(err)}`);
    return {
      shouldContinue: false,
      reply: { text: `⚠️ 部署失败：${String(err)}` },
    };
  }
};
