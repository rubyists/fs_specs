== Welcome

Welcome to FSSpecs!

FS Specs aims to spec the entire internal infrastructure of FreeSWITCH,
available at http://www.freeswitch.org, from now on called just 'freeswitch'
one section at a time all the way through.

As a basis for mapping that internal structure, we are using FSR, also
known as FreeSWITCHer as the interface to freeswitch. I'll just call it
'fsr' from now on.

Basically, we are taking Cucumber, writing features that call out to specs
which execute some portion, or all, of a freeswitch operation. Currently, we
use RSpec under the hood. I'll just call it 'rspec'. 

The first commit of this project contains a working, _passing_ spec for a single
connection between 2 working and configured freeswitch deployments (boxes).

This is the starting point for all addition features and specs. This feature will
show that your testing infrastructure is working correctly! If this fails, nothing
else matters!

The starting point is named features/000_phone_infrastructure.feature

NOTE: Please bear in mind the '00' portion of the filename. You should order the remainder
of any addition setup you need, or specific action sets done first before you hit the real
meat of most of your feature sets, with this pattern in mind. This helps to ensure proper
flow of the feature sets themselves.

OK, now on to how to get the blasted thing on your machine. :-)


== Install

First, make sure you have git on your box, along with ruby, rubygems, etc.

We use RVM to manage our ruby environment(s) so you might want to check out
http://rvm.beginrescueend.com/rvm and install it. Once its configured, fs_spec
will fit right in, and install the ruby version we use, create and use the gemset
'fs_specs' and install the gems we use. 

Once done, cd to wherever you want to keep the testing tree. eg 'cd $HOME/projects/local'

Then execute: ``git clone git://github.com/rubyists/fs_specs.git``

Now cd fs_specs
If you have rvm installed, this next step will kick it off. it will notice our .rvmrc file
in the directory and prompt you to read it, verify it, and either trust it or deny its execution.
Once satisfied, trust it, and let it roll. It will install Ruby 1.9.3-p0, and then load the
needed gems in the 'fs_spec' gemset it creates.

When the .rvmrc file is finished being evaluated, you'll have all the tools we use. At this point,
you can simply check ``rvm info`` to make sure you are in ruby-1.9.3-p0@fs_specs


== What Next

Now is the time to check that you have connectivity between your machines you'll be using for testing.

Now edit features/000_phone_infrastructure.feature and change the (blackbird|falcon).rubyists.com
to the names of your own servers.
NOTE: This *will* be made into a configuration file, most likely YAML based. Its a TODO.

You're done! Now you can run the following command. If your connection check earlier was working correctly,
then this command should pass. Run: ``cucumber features/000_phone_infrastructure.feature``
You should see all Green if your machines are properly configured.

== What Does What?

The feature files kick off all the specs under features/step_definitions/ and this is where to find everything.
All the guts of the Testing Glory reside here. The human interface remains with Cucumber.

== Donations
  I'm proud to work on Open Source software for various Projects out there. If you feel I’ve done something 
  worthy of it, please feel free to donate some cash! It will be used to pay bills, feed my dog and I, and make 
  it easier for me to spend more time working on more Open Source projects!


  Let me say right up front! Thank you! All your donations are deeply appreciated! 
  I hope to continue to write and work on stuff people need and want!

<a href='http://www.pledgie.com/campaigns/16587'><img alt='Click here to lend your support to: Donations and make a donation at www.pledgie.com !' src='http://www.pledgie.com/campaigns/16587.png?skin_name=chrome' border='0' /></a>
