// minimal stub replicating Chart.js API surface enough to catch our own bugs
class Chart {
  constructor(ctx, config) {
    this.ctx = ctx; this.config = config;
    if (!config.data || !config.data.datasets) throw new Error('bad config');
    config.data.datasets.forEach(ds => {
      if (config.data.labels.length !== ds.data.length) {
        throw new Error('labels/data length mismatch: ' + config.data.labels.length + ' vs ' + ds.data.length);
      }
      if (ds.backgroundColor && Array.isArray(ds.backgroundColor) && ds.backgroundColor.length < ds.data.length) {
        throw new Error('not enough colors: need ' + ds.data.length + ' got ' + ds.backgroundColor.length);
      }
    });
  }
  destroy(){}
}
window.Chart = Chart;
