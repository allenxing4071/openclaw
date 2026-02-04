import type { Command } from "commander";
import { projectCreateCommand, projectDeployCommand } from "../../commands/project.js";
import { defaultRuntime } from "../../runtime.js";
import { runCommandWithRuntime } from "../cli-utils.js";

export function registerProjectCommands(program: Command) {
  const project = program
    .command("project")
    .description("Create or deploy standalone projects")
    .action(() => {
      project.help({ error: true });
    });

  project
    .command("create")
    .description("Create a deployable project scaffold")
    .option("--dir <path>", "Target directory (default: cwd or --name)")
    .option("--name <name>", "Create a new folder under cwd")
    .option("--force", "Overwrite existing files", false)
    .action(async (opts) => {
      await runCommandWithRuntime(defaultRuntime, async () => {
        await projectCreateCommand(
          {
            dir: opts.dir as string | undefined,
            name: opts.name as string | undefined,
            force: opts.force as boolean,
          },
          defaultRuntime,
        );
      });
    });

  project
    .command("deploy")
    .description("Deploy a project via docker compose")
    .option("--dir <path>", "Project directory (default: cwd)")
    .option("--compose-file <path>", "Path to docker-compose.yml")
    .option("--no-build", "Skip docker build")
    .option("--no-detach", "Run in foreground")
    .action(async (opts) => {
      await runCommandWithRuntime(defaultRuntime, async () => {
        await projectDeployCommand(
          {
            dir: opts.dir as string | undefined,
            composeFile: opts.composeFile as string | undefined,
            build: opts.build as boolean,
            detach: opts.detach as boolean,
          },
          defaultRuntime,
        );
      });
    });
}
