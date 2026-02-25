# Contributing

## Branching

- Feature 分支建议：`feat/<short-topic>`
- Fix 分支建议：`fix/<short-topic>`

## Commit convention

使用 Conventional Commits：

- `feat:` 新功能
- `fix:` 修复问题
- `refactor:` 重构（无行为变更）
- `test:` 测试相关
- `docs:` 文档更新
- `chore:` 工具链/依赖/脚手架

示例：

```text
feat(today): support replay pending sync on app foreground
fix(notification): handle cross-midnight reminder edge case
```

## Pull Request checklist

- [ ] 通过 `make lint`
- [ ] 通过 `make test`
- [ ] 补充必要文档（README 或 docs）
- [ ] 关键行为变更附带测试
