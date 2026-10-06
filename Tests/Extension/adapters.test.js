const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const adaptersDirectory = path.resolve(__dirname, "../../ChromeExtension/adapters");

test("every platform adapter implements the stable core contract", () => {
  const registrations = [];
  const context = {
    VideoBatchCore: { register: (adapter) => registrations.push(adapter) },
  };
  context.globalThis = context;

  const files = fs.readdirSync(adaptersDirectory).filter((file) => file.endsWith(".js")).sort();
  files.forEach((file) => {
    const source = fs.readFileSync(path.join(adaptersDirectory, file), "utf8");
    vm.runInNewContext(source, context, { filename: file });
  });

  assert.equal(registrations.length, files.length);
  assert.equal(new Set(registrations.map((adapter) => adapter.id)).size, registrations.length);
  registrations.forEach((adapter) => {
    assert.equal(typeof adapter.id, "string");
    assert.equal(typeof adapter.matches, "function");
    assert.equal(typeof adapter.scan, "function");
    if ("focus" in adapter) assert.equal(typeof adapter.focus, "function");
  });
});
