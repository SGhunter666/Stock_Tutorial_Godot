(function () {
  var style = getComputedStyle(document.documentElement);
  var accent = style.getPropertyValue('--accent').trim();
  var accent2 = style.getPropertyValue('--accent2').trim();
  var ink = style.getPropertyValue('--ink').trim();
  var muted = style.getPropertyValue('--muted').trim();
  var rule = style.getPropertyValue('--rule').trim();
  var bg2 = style.getPropertyValue('--bg2').trim();
  var success = style.getPropertyValue('--success').trim();
  var danger = style.getPropertyValue('--danger').trim();

  var passEl = document.getElementById('chart-pass');
  if (passEl && window.echarts) {
    var passChart = echarts.init(passEl, null, { renderer: 'svg' });
    passChart.setOption({
      animation: false,
      color: [success, danger],
      tooltip: {
        trigger: 'item',
        appendToBody: true,
        formatter: '{b}: {c} 项 ({d}%)'
      },
      title: {
        text: '100%',
        subtext: '通过率',
        left: 'center',
        top: '40%',
        textStyle: { color: ink, fontSize: 30, fontWeight: 700, fontFamily: 'Instrument Sans' },
        subtextStyle: { color: muted, fontSize: 12, fontFamily: 'Instrument Sans' }
      },
      series: [{
        type: 'pie',
        radius: ['62%', '80%'],
        center: ['50%', '50%'],
        avoidLabelOverlap: true,
        label: { show: false },
        labelLine: { show: false },
        itemStyle: { borderColor: bg2, borderWidth: 3 },
        data: [
          { value: 30072, name: '通过' },
          { value: 0, name: '失败' }
        ]
      }]
    });
    window.addEventListener('resize', function () { passChart.resize(); });
  }

  var coverageEl = document.getElementById('chart-coverage');
  if (coverageEl && window.echarts) {
    var coverageChart = echarts.init(coverageEl, null, { renderer: 'svg' });
    var labels = [
      '剧情 / 提醒',
      '职业 / 基金',
      '历史 / 复盘',
      '市场 / 交易',
      '学院 / 目录',
      '压力测试',
      '显示适配',
      '国际化'
    ];
    var values = [153, 154, 209, 582, 729, 6370, 9539, 12336];
    coverageChart.setOption({
      animation: false,
      grid: { left: 132, right: 86, top: 24, bottom: 28 },
      tooltip: {
        trigger: 'axis',
        axisPointer: { type: 'shadow' },
        appendToBody: true,
        formatter: function (params) {
          var item = params[0];
          return item.name + ': ' + Number(item.value).toLocaleString('en-US') + ' 项检查';
        }
      },
      xAxis: {
        type: 'value',
        axisLabel: { color: muted, fontSize: 11 },
        splitLine: { lineStyle: { color: rule, type: 'dashed' } },
        axisLine: { show: false }
      },
      yAxis: {
        type: 'category',
        data: labels,
        axisLabel: { color: ink, fontSize: 12 },
        axisTick: { show: false },
        axisLine: { lineStyle: { color: rule } }
      },
      series: [{
        type: 'bar',
        data: values,
        barWidth: 16,
        itemStyle: {
          color: accent,
          borderRadius: [0, 4, 4, 0]
        },
        label: {
          show: true,
          position: 'right',
          color: ink,
          fontSize: 11,
          fontFamily: 'JetBrains Mono',
          formatter: function (params) {
            return Number(params.value).toLocaleString('en-US');
          }
        }
      }]
    });
    window.addEventListener('resize', function () { coverageChart.resize(); });
  }
})();
