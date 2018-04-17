---
layout: post
title: GNSS receiver testing
lang: en
categories: [english]
tags: [GNSS, C++]
comments: true
---

And now, back to business. I have abig topic to discuss and maybe I'll split it into several parts. 

Imagine any good project lifecylce:

<script async  type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>

<script async  type="text/javascript">
  google.charts.load("current", {packages:["timeline"]});
  google.charts.setOnLoadCallback(drawChart);
  function drawChart() {
    var container = document.getElementById('example2.1');
    var chart = new google.visualization.Timeline(container);
    var dataTable = new google.visualization.DataTable();

    dataTable.addColumn({ type: 'string', id: 'Term' });
    dataTable.addColumn({ type: 'string', id: 'Name' });
    dataTable.addColumn({ type: 'date', id: 'Start' });
    dataTable.addColumn({ type: 'date', id: 'End' });

    dataTable.addRows([
          ['1', 'Hardware', new Date(2017, 1, 1), new Date(2017, 6, 1)],
          ['2', 'Software', new Date(2017, 3, 1), new Date(2017, 9, 1)],
          ['3', 'Integration and testing', new Date(2017, 6, 1), new Date(2017, 12, 1)]]
      );

    chart.draw(dataTable);
  }
</script>

<div id="example2.1" style="height: 200px;"></div>

