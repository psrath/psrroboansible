from robot.api import ResultVisitor

class ResultModifier(ResultVisitor):

    def visit_suite(self, suite):
      if len(suite.suites) > 0:
        suite.name = "All Plugins Test Suites"
        suite.suites.visit(self)
      else:
        suite.name = suite.metadata['SuiteName'] + ' [ ' + suite.metadata['Plugin OS'] \
                     + ' On ' + suite.metadata['PROXMOX'] + ' ]'