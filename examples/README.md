# 示例产物

`run-ci-demo/` 是一次**真实跑通**的最小实验留下的东西，不是手写的示意文件。
同样的流程每次 push 都会在 [CI](../.github/workflows/ci.yml) 里重跑一遍，绿灯即代表它现在仍然成立。

```
run-ci-demo/
  ci-demo.log              完整日志，含每步耗时
  ALLDONE_ci-demo          完成标记：起止时间、代码快照位置、日志位置
  results/ci-demo/
    code/train.py          起跑时复制的代码快照
    best.pth               权重（本例是占位内容）
    RESULT.txt             指标
```

它证明的是**机制**：一次运行确实会留下独立目录、代码快照、日志和完成标记，
而失败时不会留下完成标记。它**不是**论文级实验结果——那部分数据不在本仓库。
