---
layout: post
title: GNSS receiver testing (hardware)
lang: en
categories: [english]
tags: [GNSS]
comments: true
---

Now, back to business. I have a big topic to discuss and maybe I will split it into several parts. 

Imagine any good project lifecycle:

<script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>

<script type="text/javascript">
  google.charts.load("current", {packages:["timeline"]});
  google.charts.setOnLoadCallback(drawChart);
  function drawChart() {
    var container = document.getElementById('lifecycle');
    var chart = new google.visualization.Timeline(container);
    var dataTable = new google.visualization.DataTable();

    dataTable.addColumn({ type: 'string', id: 'Term' });
    dataTable.addColumn({ type: 'string', id: 'Name' });
    dataTable.addColumn({ type: 'date', id: 'Start' });
    dataTable.addColumn({ type: 'date', id: 'End' });

    dataTable.addRows([
          ['1', 'Hardware', new Date(2017, 0, 1), new Date(2017, 6, 1)],
          ['2', 'Software', new Date(2017, 1, 1), new Date(2017, 10, 1)],
          ['3', 'Integration and testing', new Date(2017, 4, 1), new Date(2017, 11, 1)]]
      );

    chart.draw(dataTable);
  }
</script>
<div id="lifecycle" style="height: 180px;"></div>

The more those activities overlap the better. It means that your process is well defined and there are various models and stuff available to make your departments independent upon work results. 

Surely, this chart does not represent all of the interaction between departments, feedback and last minute calls, but most of the time it is correct. 

# Hardware testing

> Disclaimer: In this section, I am talking about board development. FPGA or ASIC development is specific in its own way with higher price of the mistake, but generally the same.

Let us separate the process into two subtasks:

- [Testing during the development](#testing-during-the-development)
  - Modelling
  - Prototyping
- [Testing with the board on the desk with various test and measurement equipment](#testing-with-the-board-on-the-desk-with-various-test-and-measurement-equipment)

From the developers point of view it can be compared with compile- and run-time checks. :)

## Testing during the development

This is the most important part which is often (quite unfortunately) being overlooked and ignored. There is a lot of great software to make hardware engineers' life easier. Check out the Keysight software kit (Genesys, ADS, etc), Multisim and LTSpice.

Different tools are good for different tasks. As far as I am aware, out hardware department uses LTSpice for power circuits, Genesys for analog filters and Multisim for various digital signal chains. 

Prototyping is a little bit different. You take part of your schematic and develop (or buy an evaluation board, if you are lucky) a little piece of hardware to test. 

There are several reasons to go with prototyping instead of modelling:
- Lack of authentic component models. Usually this happens with small manufacturers, programmable devices or semi-custom components
- RF devices. Microwave is an extremely interesting field of radioelectronics with lots of "implementation-specific" details. Quite often model results vary very much from practice, because of the tracing details.

## Testing with the board on the desk with various test and measurement equipment

All right, after all those long months you have your hands on the board. If you are lucky enough, your software engineers will load their programs and everything works just fine. Otherwise, it's time to unleash all of the equipment.

First, it is always a good idea to test all of your I/O pins. Test their read and write ability, timings and frequencies. This a very low-level test, which should be incorporated into the assembling routine of the board. 

Then we have to make sure that every chip that we have on the board is functional. The vast majority of them have some kind of identification register, which can be used as a sign that device works. 

Now it is time to unleash all of the equipment power. By providing different test signals (sine is good for almost everything) and probing various test points, it is possible to find where everything goes haywire. 

It is quite possible that the signal is good and something is wrong in your DSP algorithms. That the signal is somewhat different from what you are expecting. 

A little summary:

1. Test I/O pins
2. Test surrounding chips
3. Check signal flow and test points
4. Redirect the problem back to the software department and check the algorithms. 

Okay, hardware part is over, software is yet to come. Stay tuned. 