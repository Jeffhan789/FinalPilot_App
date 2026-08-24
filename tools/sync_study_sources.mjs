#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const projectRoot = process.cwd();
const appSnapshotPath = path.join(projectRoot, "FinalPilotApp", "StudySyncSnapshot.json");
const dataSnapshotPath = path.join(projectRoot, "data", "study_sync_snapshot.json");
const appLocalSnapshotPath = path.join(projectRoot, "FinalPilotApp", "StudySyncSnapshot.local.json");
const dataLocalSnapshotPath = path.join(projectRoot, "data", "study_sync_snapshot.local.json");
const sourcesConfigPath = path.join(projectRoot, "tools", "sync_sources.local.json");
const defaultPort = 8787;

function loadSources() {
  if (!fs.existsSync(sourcesConfigPath)) {
    throw new Error(`Missing local config: ${sourcesConfigPath}`);
  }
  const config = JSON.parse(fs.readFileSync(sourcesConfigPath, "utf8"));
  if (!Array.isArray(config.sources) || config.sources.length === 0) {
    throw new Error("tools/sync_sources.local.json must contain a non-empty sources array.");
  }
  return config.sources;
}

const scoreRules = [
  [/00-每日任务看板/i, 120, "daily_board"],
  [/每日任务看板/i, 110, "daily_board"],
  [/06-.*每日具体任务|每日具体任务安排/i, 100, "daily_plan"],
  [/README-总计划|总计划/i, 92, "master_plan"],
  [/双列课件笔记优化版|课件笔记优化版/i, 126, "flashcard_source"],
  [/A4-两周复习进度规划表/i, 88, "a4_plan"],
  [/执行清单|今日复习记录|Day\d|Day[一二三四五六七八九十]/i, 82, "execution_log"],
  [/真题矩阵|错题|错因|复盘/i, 74, "practice_feedback"],
  [/科学复习计划|机动缓冲|A.?B.?C|三档/i, 64, "scheduling_rule"],
  [/资料索引|打印清单|笔记规范|题型整理/i, 48, "reference_index"]
];

const readableExtensions = new Set([".md", ".txt", ".html", ".pdf"]);
const metadataExtensions = new Set([".docx", ".pages"]);

function walk(rootPath, depth = 0, maxDepth = 6, out = []) {
  if (depth > maxDepth || !fs.existsSync(rootPath)) return out;
  let entries = [];
  try {
    entries = fs.readdirSync(rootPath, { withFileTypes: true });
  } catch {
    return out;
  }

  for (const entry of entries) {
    if (entry.name.startsWith(".")) continue;
    const fullPath = path.join(rootPath, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath, depth + 1, maxDepth, out);
      continue;
    }
    out.push(fullPath);
  }
  return out;
}

function scoreFile(filePath) {
  const normalized = filePath.replaceAll("\\", "/");
  const ext = path.extname(filePath).toLowerCase();
  if (!readableExtensions.has(ext) && !metadataExtensions.has(ext)) return null;

  let score = 0;
  let kind = "reference";
  for (const [pattern, points, ruleKind] of scoreRules) {
    if (pattern.test(normalized)) {
      score += points;
      kind = ruleKind;
    }
  }

  if (normalized.includes("/复习规划同步/")) score += 36;
  if (normalized.includes("00-C310_E320-高效复习总控")) score += 24;
  if (normalized.includes("/C310-0-期末考试") || normalized.includes("/E320-0-期末考试")) score += 18;
  if (ext === ".pdf" && !/A4-两周复习进度规划表|Day|双列课件笔记|课件笔记|讲义|指南/i.test(normalized)) score -= 30;

  if (score <= 0) return null;
  return { score, kind };
}

function fileMetadata(filePath, source) {
  const stat = fs.statSync(filePath);
  const scored = scoreFile(filePath);
  if (!scored) return null;
  return {
    id: Buffer.from(filePath).toString("base64url").slice(0, 16),
    sourceId: source.id,
    courseCode: source.courseCode,
    title: path.basename(filePath),
    relativePath: path.relative(source.rootPath, filePath),
    absolutePath: filePath,
    extension: path.extname(filePath).toLowerCase().replace(".", ""),
    kind: scored.kind,
    score: scored.score,
    modifiedAt: stat.mtime.toISOString(),
    size: stat.size
  };
}

function extractText(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  try {
    if (ext === ".md" || ext === ".txt") {
      return fs.readFileSync(filePath, "utf8");
    }
    if (ext === ".html") {
      return fs.readFileSync(filePath, "utf8")
        .replace(/<script[\s\S]*?<\/script>/gi, " ")
        .replace(/<style[\s\S]*?<\/style>/gi, " ")
        .replace(/<[^>]+>/g, " ")
        .replace(/&nbsp;/g, " ");
    }
    if (ext === ".pdf") {
      return execFileSync("pdftotext", ["-layout", filePath, "-"], {
        encoding: "utf8",
        maxBuffer: 2 * 1024 * 1024
      });
    }
  } catch {
    return "";
  }
  return "";
}

function cleanLine(line) {
  return line.replace(/\s+/g, " ").trim();
}

function buildExcerpt(text) {
  const important = text
    .split(/\r?\n/)
    .map(cleanLine)
    .filter(Boolean)
    .filter(line => (
      /\[[ xX]\]|C310|E320|5\/\d+|2026-05|真题|错题|复盘|今日|明天|Must|Should|Skip|A 档|B 档|C 档|保底/.test(line)
    ));
  return important.slice(0, 8);
}

function parseTasks(text, file, source) {
  const tasks = [];
  const lines = text.split(/\r?\n/);
  lines.forEach((line, index) => {
    const checkbox = line.match(/^\s*[-*]\s+\[([ xX])\]\s+(.+)$/);
    if (!checkbox) return;
    const title = cleanLine(checkbox[2]);
    if (!title) return;

    const inferredCourse = /E320|神经网络|NN|perceptron|backprop|SVM|SOM|RBF/i.test(title)
      ? "E320"
      : /C310|多智能体|Agent|BDI|Shapley|coalition|ontology/i.test(title)
        ? "C310"
        : source.courseCode;

    tasks.push({
      id: `${file.id}_${index + 1}`,
      courseCode: inferredCourse,
      title,
      done: checkbox[1].toLowerCase() === "x",
      sourceTitle: file.title,
      sourcePath: file.absolutePath,
      line: index + 1
    });
  });
  return tasks;
}

function buildSnapshot() {
  const sources = loadSources();
  const generatedAt = new Date().toISOString();
  const selectedFiles = [];
  const sourceSummaries = [];
  const taskItems = [];

  for (const source of sources) {
    const allFiles = walk(source.rootPath);
    const files = allFiles
      .map(filePath => {
        try {
          return fileMetadata(filePath, source);
        } catch {
          return null;
        }
      })
      .filter(Boolean)
      .sort((lhs, rhs) => rhs.score - lhs.score || new Date(rhs.modifiedAt) - new Date(lhs.modifiedAt))
      .slice(0, 14);

    for (const file of files) {
      const text = readableExtensions.has(`.${file.extension}`) ? extractText(file.absolutePath) : "";
      file.excerpt = buildExcerpt(text);
      selectedFiles.push(file);
      taskItems.push(...parseTasks(text, file, source));
    }

    const latestModifiedAt = files
      .map(file => file.modifiedAt)
      .sort()
      .at(-1) ?? null;

    sourceSummaries.push({
      id: source.id,
      courseCode: source.courseCode,
      title: source.title,
      rootPath: source.rootPath,
      exists: fs.existsSync(source.rootPath),
      filesScanned: allFiles.length,
      selectedFiles: files.length,
      latestModifiedAt
    });
  }

  const totalTasks = taskItems.length;
  const doneTasks = taskItems.filter(task => task.done).length;
  const openTasks = taskItems.filter(task => !task.done);
  const suggestedToday = openTasks.slice(0, 10);

  return {
    schemaVersion: 1,
    generatedAt,
    localServiceUrl: `http://127.0.0.1:${defaultPort}/study-sync-snapshot.json`,
    syncMode: "local_fixed_paths",
    selectionPolicy: "优先同步每日任务看板、总计划、每日具体安排、最新双列课件笔记、A4 两周规划、真题矩阵、错题和执行清单；普通课件 PDF 只做低优先级元数据。",
    sources: sourceSummaries,
    metrics: {
      selectedFiles: selectedFiles.length,
      totalTasks,
      doneTasks,
      openTasks: totalTasks - doneTasks,
      completionRate: totalTasks === 0 ? 0 : doneTasks / totalTasks
    },
    suggestedToday,
    selectedFiles
  };
}

function redactSnapshot(snapshot) {
  return {
    ...snapshot,
    privacyNote: "This tracked snapshot is redacted for GitHub. Run --serve locally to view full fixed-path details in the simulator.",
    sources: snapshot.sources.map(source => ({
      ...source,
      rootPath: "固定路径已隐藏；本机实时服务会读取真实路径"
    })),
    suggestedToday: [],
    selectedFiles: snapshot.selectedFiles.map((file, index) => ({
      ...file,
      id: `redacted_file_${String(index + 1).padStart(3, "0")}`,
      absolutePath: "",
      excerpt: ["已选中该进度文件；开启本地实时服务后显示真实摘要。"]
    }))
  };
}

function writeSnapshot(snapshot) {
  const redactedJson = `${JSON.stringify(redactSnapshot(snapshot), null, 2)}\n`;
  const localJson = `${JSON.stringify(snapshot, null, 2)}\n`;
  fs.writeFileSync(appSnapshotPath, redactedJson);
  fs.writeFileSync(dataSnapshotPath, redactedJson);
  fs.writeFileSync(appLocalSnapshotPath, localJson);
  fs.writeFileSync(dataLocalSnapshotPath, localJson);
}

function printUsage() {
  console.log(`Usage:
  node tools/sync_study_sources.mjs --write
  node tools/sync_study_sources.mjs --serve [--port 8787]
  node tools/sync_study_sources.mjs --print

Before running, create tools/sync_sources.local.json from tools/sync_sources.example.json.`);
}

function serve(port) {
  const server = http.createServer((request, response) => {
    if (!request.url?.startsWith("/study-sync-snapshot.json")) {
      response.writeHead(404, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ error: "not_found" }));
      return;
    }

    const snapshot = buildSnapshot();
    writeSnapshot(snapshot);
    response.writeHead(200, {
      "Access-Control-Allow-Origin": "*",
      "Cache-Control": "no-store",
      "Content-Type": "application/json; charset=utf-8"
    });
    response.end(JSON.stringify(snapshot, null, 2));
  });

  server.listen(port, "127.0.0.1", () => {
    console.log(`FinalPilot sync bridge listening at http://127.0.0.1:${port}/study-sync-snapshot.json`);
    console.log("Leave this running while reviewing the iOS simulator. Press Ctrl+C to stop.");
  });
}

const args = process.argv.slice(2);
if (args.includes("--help") || args.length === 0) {
  printUsage();
} else if (args.includes("--serve")) {
  const portIndex = args.indexOf("--port");
  const port = portIndex >= 0 ? Number(args[portIndex + 1]) : defaultPort;
  serve(Number.isFinite(port) ? port : defaultPort);
} else if (args.includes("--print")) {
  console.log(JSON.stringify(buildSnapshot(), null, 2));
} else if (args.includes("--write")) {
  const snapshot = buildSnapshot();
  writeSnapshot(snapshot);
  console.log(`Wrote redacted tracked snapshot plus local private snapshot.`);
  console.log(`Selected ${snapshot.metrics.selectedFiles} files and ${snapshot.metrics.totalTasks} task items.`);
} else {
  printUsage();
  process.exitCode = 1;
}
