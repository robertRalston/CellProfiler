'''macros.py - helper methods for finding and running macros'''
# CellProfiler is distributed under the GNU General Public License.
# See the accompanying file LICENSE for details.
#
# Developed by the Broad Institute
# Copyright 2003-2011
# 
# Please see the AUTHORS file for credits.
#
# Website: http://www.cellprofiler.org
#
__version__="$Revision$"

import sys

import bioformats
import cellprofiler.utilities.jutil as J

from cellprofiler.preferences import get_headless

def get_commands():
    '''Return a list of the available command strings'''
    def fn():
        hashtable = J.static_call('ij/Menus', 'getCommands',
                                  '()Ljava/util/Hashtable;')
        if hashtable is None:
            #
            # This is a little bogus, but works - trick IJ into initializing
            #
            execute_command("pleaseignorethis")
            hashtable = J.static_call('ij/Menus', 'getCommands',
                                      '()Ljava/util/Hashtable;')
            if hashtable is None:
                return []
        keys = J.call(hashtable, "keys", "()Ljava/util/Enumeration;")
        keys = J.jenumeration_to_string_list(keys)
        values = J.call(hashtable, "values", "()Ljava/util/Collection;")
        values = [J.to_string(x) for x in J.iterate_java(
            J.call(values, 'iterator', "()Ljava/util/Iterator;"))]
        class CommandList(list):
            def __init__(self):
                super(CommandList, self).__init__(keys)
                self.values = values
        return CommandList()
    return J.run_in_main_thread(fn, True)
        
def execute_command(command, options = None):
    '''Execute the named command within ImageJ'''
    def fn(command=command, options=options):
        if options is None:
            J.static_call("ij/IJ", "run", "(Ljava/lang/String;)V", command)
        else:
            J.static_call("ij/IJ", "run", 
                          "(Ljava/lang/String;Ljava/lang/String;)V",
                          command, options)
    J.run_in_main_thread(fn, True)
    
def execute_macro(macro_text):
    '''Execute a macro in ImageJ
    
    macro_text - the macro program to be run
    '''
    def fn(macro_text = macro_text):
        show_imagej()
        interp = J.make_instance("ij/macro/Interpreter","()V")
        J.call(interp, "run","(Ljava/lang/String;)V", macro_text)
    J.run_in_main_thread(fn, True)
    
def show_imagej():
    '''Show the ImageJ user interface'''
    ij_obj = J.static_call("ij/IJ", "getInstance", "()Lij/ImageJ;")
    if ij_obj is None:
        ij_obj = J.make_instance("ij/ImageJ", "()V")
    J.call(ij_obj, "setVisible", "(Z)V", True)
    J.call(ij_obj, "toFront", "()V")
    
def get_user_loader():
    '''The class loader used to load user plugins'''
    return J.static_call("ij/IJ", "getClassLoader", "()Ljava/lang/ClassLoader;")

def get_plugin(classname):
    '''Return an instance of the named plugin'''
    if classname.startswith("ij."):
        cls = J.class_for_name(classname)
    else:
        cls = J.class_for_name(classname, get_user_loader())
    cls = J.get_class_wrapper(cls, True)
    constructor = J.get_constructor_wrapper(cls.getConstructor(None))
    return constructor.newInstance(None)

if __name__=="__main__":
    import sys
    J.attach()
    try:
        commands = get_commands()
        print "Commands: "
        for command in commands:
            print "\t" + command
        if len(sys.argv) == 2:
            execute_command(sys.argv[1])
        elif len(sys.argv) > 2:
            execute_command(sys.argv[1], sys.argv[2])
        
    finally:
        J.detach()
        J.kill_vm()
