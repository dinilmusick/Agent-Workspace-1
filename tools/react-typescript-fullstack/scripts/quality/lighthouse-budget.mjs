export function evaluateLighthouseRuns(reports, config) {
  const failures = [];
  const categories = {};
  const metrics = {};
  const categoryThresholds = config.categoryThresholds ?? {};
  const metricBudgets = config.metricBudgets ?? {};

  for (const [category, minimum] of Object.entries(categoryThresholds)) {
    const scores = reports.map(report => report.categories?.[category]?.score).filter(Number.isFinite);
    const average = scores.length ? scores.reduce((sum, score) => sum + score, 0) / scores.length : null;
    categories[category] = { average, minimum, passed: average !== null && average >= minimum };
    if (!categories[category].passed) failures.push(category + " score " + (average ?? "missing") + " is below " + minimum);
  }

  for (const [metric, maximum] of Object.entries(metricBudgets)) {
    const values = reports.map(report => report.audits?.[metric]?.numericValue).filter(Number.isFinite).sort((a, b) => a - b);
    const median = values.length
      ? values.length % 2 ? values[(values.length - 1) / 2] : (values[values.length / 2 - 1] + values[values.length / 2]) / 2
      : null;
    metrics[metric] = { median, maximum, passed: median !== null && median <= maximum };
    if (!metrics[metric].passed) failures.push(metric + " median " + (median ?? "missing") + " exceeds " + maximum);
  }

  return { passed: failures.length === 0, categories, metrics, failures, runs: reports.length };
}
