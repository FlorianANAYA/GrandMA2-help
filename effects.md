


# Creating effects completely from CLI in GrandMA2
The official GrandMA2 help pages show how to create effects using their interface but don't explicitly show how to create and tweak them entirely from the CLI.
Even though it fells easy, there is no documentation on how to edit every options of an effect by commands in GrandMa2.
This tutorial is here to show how to create and edit an effect entirely from CLI. This is particularly useful if you want to create a macro that makes your effects for you.

There are a lot of parameters in an effect and some of them are a bit tricky to edit.
## Main principles
There are general rules that have to be followed.

 - When referencing an effect pool number, it has to start by a pool id which is always 1. Sometimes it works without it, but it is generally a good idea to reference effects with `Effect 1.25` instead of `Effect 25`. This is because MALighting wanted to be able to add in future release several effect pools in order to organize work, but they never did yet.
 - The creation of the effect uses the programmer so it is a good idea to start with `ClearAll` and why not `BlindEdit On`.
 - There are a lot of parameters that are edited with `/parameter="value"`. Those parameters can be added together in only one command like this : `Assign Effect 1.25.1 /groups=2 /wings=2`.


## Create the effect
The first step is of course to create the effect.

    Store Effect 1.1
This command stores effects currently located in the programmer in the effect #1. If your programmer was empty, it will just create an empty template effect. You can label your effect with the following command (don't forget to put quotation marks in order to avoid troubles) :

    Label Effect 1.1 "Some fancy name"
## Create lines
The basic command to create a line in an effect is the following :

    Store Effect 1.25.1
Where `1` is the pool id, `25` is the effect number and `1` is the line number we are creating. The line number cannot be greater than the current line count plus one (so `Store Effect 1.25.2` on an empty effect will produce an error).
Executing this command will include the current selection of fixture in the line. Of course, if you don't have fixtures selected, your line will not contain any fixture and your effect will keep being template.
If you have fixture selected, you may be prompted with the store method popup.
This can be avoided by adding the `/o` parameter to your command.

    Store Effect 1.25.1 /o

In order to create multiple lines with one command, you can just execute

    Store Effect 1.25.1 Thru 1.25.4 /o
This will create several lines with corresponding numbers but, by doing this, something weird happens : the fixture selection only applies to the last line.
This is because, for some reason, it is not possible to have multiple lines with the same fixture selection and no attribute. To fix that, it is mandatory to create a line, assign its attribute, before creating a second line.

    Store Effect 1.25.1 /o
    Assign Attribute "colorrgb1" Effect 1.25.1
    Store Effect 1.25.2 /o
    Assign Attribute "colorrgb2" Effect 1.25.2
    Store Effect 1.25.3 /o
    Assign Attribute "colorrgb3" Effect 1.25.3
See more about assigning attributes in the corresponding section.

## Edit interleave
The edition of the interleave is part of the very easy operations that are pretty straightforward.

    Assign Effect 1.25.1 /interleave="Odd"
    Assign Effect 1.25.1 Thru 1.25.4 /interleave="1 of 4"
    
Don't forget to put the interleave mode in quotation mark. Every interleave can be used this way, they just have to be written at the exact same.

## Assign attributes for lines
The method to edit effect lines attribute is consistent. You can use either the attribute number or its name. Nevertheless, it is recommended to only use the names because the numbers change between fixtures.

    Assign Attribute "pan" Effect 1.25.1
    Assign Attribute 1 Effect 1.25.1 Thru 1.25.2
## Absolute / relative mode

    Assign Effect 1.25.1 /mode="abs"
    Assign Effect 1.25.1 Thru 1.25.4 /mode="rel"
## Forms
The name of the forms cannot be used, the form pool id must be used in the command. User-made forms can also be used. 

    Assign Form 1 Effect 1.25.1
    Assign Form 13 Effect 1.25.1 Thru 1.25.4
It is also possible to assign a specific form graph to a line.

    Assign Form 19.1 Effect 1.25.1
    Assign Form 19.2 Effect 1.25.2
## Editing rate
Editing the rate from the CLI will, like in UI, modify the speed accordingly.

    Assign Effect 1.25.1 /rate=1
    Assign Effect 1.25.1 Thru 1.25.4 /rate=0.25
## Editing Speed
Editing the speed form CLI will, just like in UI, modify the rate accordingly.

    Assign Effect 1.25.1 /speed=60
    Assign Effect 1.25.1 Thru 1.25.4 /speed=30
## Editing speed group
Editing the speed group is as easy as it is to modify the speed of the effect. However, it is important to specify the exact title of the speed master you want to use. It is unfortunately impossible to reference speed master with its number (like `1` or `3.1`). 

    Assign Effect 1.25.1 /speedgroup="Speed 1"
    Assign Effect 1.25.1 Thru 1.25.4 /speedgroup="Mouvs speed"
If two speed master have the same name, it looks like MA chooses the first one in the list. However I don't know a single good reason to have two speed masters with the same name.
Typing an invalid name will remove the speed group. 

    Assign Effect 1.25.1 /speedgroup="some group name that doesnt exist"

However, trying an empty name or no name at all will not change the current assigned speed group.

    Assign Effect 1.25.1 /speedgroup=""
    Assign Effect 1.25.1 /speedgroup=
## Change direction

    Assign Effect 1.25.1 /dir=">"
	Assign Effect 1.25.1 Thru 1.25.2 /dir="<"
	Assign Effect 1.25.1 /dir=">Bounce"
	Assign Effect 1.25.1 /dir="<Bounce"
## Changing Low and high values

**On relative effect**
Changing low and high values on relative effect is easy.

    Assign Effect 1.25.1 /lowvalue=0
    Assign Effect 1.25.1 /highvalue=90
    Assign Effect 1.25.1 Thru 1.25.2 /lowvalue=-45 /highvalue=45
**On absolute effects**
Changing low and High values on absolute effects is a bit more tricky. The value has to be stored in the programmer effect layer. 
If your effect is selective, the fixtures must first be selected. It is not possible to edit line by line. Rather, the attributes have to be modified and inserted in the actual effect. The corresponding lines will be modified accordingly. Here, `/m` is used to merge the informations contained in the programmer's effect and the actual effect.

    Attribute "pan" At EffectLow 0
    Attribute "tilt" At EffectHigh 90
    Store Effect 1.25 /m
It is also possible to reference preset to low and high values.

    At preset 1.3.1 /layer=EffectLow
    At preset 1.3.1 /layer=EffectHigh
    Store Effect 1.25 /m
Preset id are defined like this:
 - `1` is mandatory
 - `2` is the pool type number. Dimmer pool is 1, position pool is 2, gobo pool is 3 and so on
 - `1` is the pool element that is to be used
So in the example above, we are using the position preset #1
## Other parameters
Every other parameters (groups, wings, decay, etc) are quite easy to use so here they are in the same paragraphe. Every one of them can be added together and can use the `Thru` keyword to assign several lines at the same time.
If you try to edit a parameter that is deactivated (like the Phase with a Random form), the command will throw an error. 

    Assign Effect 1.25.1 /phase=0
    Assign Effect 1.25.1 /width=100
    Assign Effect 1.25.1 /attack=10
    Assign Effect 1.25.1 /decay=10
    Assign Effect 1.25.1 /groups=2
    Assign Effect 1.25.1 /blocks=2
    Assign Effect 1.25.1 /wings=2
    Assign Effect 1.25.1 /singleshot="yes"
    Assign Effect 1.25.1 /singleshot="no"
It is also possible to use `Thru` values this way

    Assign Effect 1.25.1 /phase="0..360"
