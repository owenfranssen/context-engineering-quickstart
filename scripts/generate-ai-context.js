#!/usr/bin/env node
/**
 * generate-ai-context.js
 *
 * Generates docs/ai/auto-context.md — a snapshot of key source files for AI
 * consumption. Run after significant code changes to keep context fresh.
 *
 * Usage:
 *   node scripts/generate-ai-context.js
 *   node scripts/generate-ai-context.js --dry-run
 *
 * Configure via generate-ai-context.config.js in your project root, or
 * edit the defaultConfig below.
 */

const fs = require('fs');
const path = require('path');

// ─── Configuration ─────────────────────────────────────────────────────────

const defaultConfig = {
  // Output file — the generated context snapshot
  output: 'docs/ai/auto-context.md',

  // Max file size to include
  maxBytes: 120_000,   // 120KB
  maxLines: 1200,

  // Glob patterns to include (uses micromatch syntax)
  include: [
    'src/**/*.{js,ts,jsx,tsx}',
    'docs/**/*.md',
    // Add your patterns:
    // 'api/src/**/*.ts',
    // 'shared/**/*.ts',
  ],

  // Patterns to always exclude
  exclude: [
    '**/node_modules/**',
    '**/dist/**',
    '**/build/**',
    '**/.next/**',
    '**/*.min.js',
    '**/*.map',
    '**/coverage/**',
    '**/*.lock',
    'docs/ai/auto-context.md', // don't include the output in itself
  ],

  // Files to always include regardless of size (high-signal anchors)
  alwaysInclude: [
    // 'docs/architecture.md',
    // 'docs/glossary.md',
  ],
};

// Load project-level config override if present
let config = defaultConfig;
const configPath = path.join(process.cwd(), 'generate-ai-context.config.js');
if (fs.existsSync(configPath)) {
  const override = require(configPath);
  config = { ...defaultConfig, ...override };
}

// ─── Binary detection ──────────────────────────────────────────────────────

function isBinary(buf) {
  const slice = buf.slice(0, 8000);
  let control = 0;
  for (const b of slice) {
    if (b === 9 || b === 10 || b === 13) continue; // tab, LF, CR
    if (b < 32 || b === 127) control++;
  }
  return control / slice.length > 0.3;
}

// ─── File collection ───────────────────────────────────────────────────────

function matchesPattern(filePath, patterns) {
  const { minimatch } = (() => {
    try { return require('minimatch'); }
    catch { return { minimatch: (f, p) => f.includes(p.replace(/\*/g, '')) }; }
  })();
  return patterns.some(p => minimatch(filePath, p, { matchBase: true }));
}

function collectFiles(dir, config) {
  const results = [];

  function walk(current) {
    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      const rel = path.relative(process.cwd(), full);

      if (entry.isDirectory()) {
        if (!matchesPattern(rel + '/', config.exclude)) walk(full);
        continue;
      }

      if (matchesPattern(rel, config.exclude)) continue;
      if (!matchesPattern(rel, config.include) && !config.alwaysInclude.includes(rel)) continue;

      try {
        const stat = fs.statSync(full);
        if (stat.size > config.maxBytes && !config.alwaysInclude.includes(rel)) continue;

        const buf = fs.readFileSync(full);
        if (isBinary(buf)) continue;

        const content = buf.toString('utf8');
        const lineCount = content.split('\n').length;
        if (lineCount > config.maxLines && !config.alwaysInclude.includes(rel)) continue;

        results.push({ path: rel, content, size: stat.size, lines: lineCount });
      } catch {
        // skip unreadable files
      }
    }
  }

  walk(dir);
  return results.sort((a, b) => a.path.localeCompare(b.path));
}

// ─── Output generation ─────────────────────────────────────────────────────

function generate(dryRun = false) {
  const files = collectFiles(process.cwd(), config);

  const header = [
    '<!-- AUTO-GENERATED — do not edit by hand. Run: node scripts/generate-ai-context.js -->',
    `<!-- Generated: ${new Date().toISOString()} -->`,
    `<!-- Files: ${files.length} -->`,
    '',
    '# AI Context Snapshot',
    '',
    '> This file is a generated snapshot for AI consumption. Not primary navigation — ',
    '> treat as a last-resort fallback. For structured context see docs/ai/README.md.',
    '',
  ].join('\n');

  const body = files.map(f => [
    `## ${f.path}`,
    `<!-- ${f.lines} lines, ${Math.round(f.size / 1024)}KB -->`,
    '```' + (f.path.endsWith('.ts') || f.path.endsWith('.tsx') ? 'typescript'
            : f.path.endsWith('.js') || f.path.endsWith('.jsx') ? 'javascript'
            : f.path.endsWith('.md') ? 'markdown' : ''),
    f.content.trimEnd(),
    '```',
    '',
  ].join('\n')).join('\n');

  const output = header + body;

  if (dryRun) {
    console.log(`[dry-run] Would write ${files.length} files to ${config.output}`);
    console.log(`[dry-run] Output size: ${Math.round(output.length / 1024)}KB`);
    return;
  }

  const outputDir = path.dirname(path.join(process.cwd(), config.output));
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(path.join(process.cwd(), config.output), output, 'utf8');
  console.log(`✅ Wrote ${files.length} files → ${config.output} (${Math.round(output.length / 1024)}KB)`);
}

// ─── Run ───────────────────────────────────────────────────────────────────

const dryRun = process.argv.includes('--dry-run');
generate(dryRun);
