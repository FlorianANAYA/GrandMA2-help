

# Editing forms from CLI
It is possible to create and edit forms and their graphs entirely from command line interaction.
First you should be familiar with how [forms](https://help2.malighting.com/Page/grandMA2/effects_create_forms/en/3.7) work in GrandMA2. To recap, forms are made of graphs that are made of points.
## Creating the form
Let's start by creating the form itself. It can labeled with the same command.

    Store Form 30
    Store Form 30 "Some Name"
When you create a form, it automatically comes with a graph that contains two points.
It is also possible to delete it easily with the following command 

    Delete Form 30
## Creating graphs
Creating graphs is as easy. Forms by default come with one graph so it is generally not necessary to create the first one.

    Store Form 30.1
    Store Form 30.2
    Delete Form 30.1
## Creating points in graphs
It is possible to create and edit points in a graph the same way it is possible to create graphs. When a graph is created, it comes with the two first points so it is generally not necessary to create them.

    Store Form 1.30.1
    Store Form 1.30.2
    Store Form 1.30.3
It is also possible to create several points at the same time.

    Store Form 1.30.4 Thru 1.30.6
It is important to note that there is a display bug. When you create points this way, if you look at those with the UI, you will see that the order is messed up until you edit the point coordinates.
## Editing points coordinates
Editing points is very straightforward. 

    Assign Form 30.1.1 /x=0
    Assign Form 30.1.1 /y=100
    Assign Form 30.1.1 /mode="Splite"
It is also possible to edit several properties at the same time and also edit several points together.

    Assign Form 30.1.1 /x=0 /y=25 /mode="Splite"
    Assign Form 30.2.1 Thru 30.2.4 /x=25 /y=25 /mode="Step (start)"
