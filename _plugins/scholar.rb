# Copyright 2014 Luís Pina
#
# This file is part of Luís Pina personal website.
#
#    Luís Pina personal website is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    Luís Pina personal website is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Luís Pina personal website.  If not, see <http://www.gnu.org/licenses/>.

require 'jekyll/scholar'
require 'latex/decode'

$authors = 	Hash.new
$authors["Luís Pina"] = "<b>Luís Pina</b>"
$authors["Michael Hicks"] = '<a href="http://www.cs.umd.edu/~mwh/" target="_blank">Michael Hicks</a>'
$authors["João Cachopo"] = '<a href="http://joao.cachopo.org/" target="_blank">João Cachopo</a>'
$authors["Luís Veiga"] = '<a href="http://www.gsd.inesc-id.pt/~lveiga/" target="_blank">Luís Veiga</a>'
$authors["Cristian Cadar"] = '<a href="http://www.doc.ic.ac.uk/~cristic/" target="_blank">Cristian Cadar</a>'

class MyFilter < BibTeX::Filter
	def apply(value)
		value = ::LaTeX.decode(value)
		# Do I know this author?
		# Hackish, I know
		value
			.split("and")
			.map{ |n| $authors.has_key?(n.strip()) ? $authors[n.strip()] : n }
			.join(" and ")
	end
end

class Details < Jekyll::Page
  include Jekyll::Scholar::Utilities

  def initialize(site, base, dir, entry)
    @site, @base, @dir = site, base, dir

    @config = Jekyll::Scholar.defaults.merge(site.config['scholar'] || {})

    @name = details_file_for(entry)

    process(@name)
    read_yaml(File.join(base, '_layouts'), config['details_layout'])

    data['entry'] = liquidify(entry)

		# Hide the abstract from bibtex
		tmp = entry.dup
		if tmp.field?(:abstract)
			tmp.delete :abstract
		end

		# Hide from bibtex all fields which name starts with "custom"
		entry.fields.each do |key, value|
			if key.to_s.start_with?('custom')
				tmp.delete key
			end
		end

		data['entry']['bibtex'] = tmp.to_s
  end

end

class MyDetailsGenerator < Jekyll::Scholar::DetailsGenerator
	def generate(site)
        @site, @config = site, Jekyll::Scholar.defaults.merge(site.config['scholar'] || {})

				# Generate details page for every entry in the bibliography
        if generate_details?
          entries.each do |entry|
            details = Details.new(site, site.source, File.join('', details_path), entry)
            details.render(site.layouts, site.site_payload)
            details.write(site.dest)

            site.pages << details
          end

        end
      end
end
