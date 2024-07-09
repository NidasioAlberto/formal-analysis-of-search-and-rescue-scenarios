#import "colors.typ": blue_polimi

#let puttitle(
  title: [Title],
  subtitle: [
    Tesi di Laurea Magistrale in \
    Xxxxxxx Engineering - Ingegneria Xxxxxxx
  ],
  authors: ("Name Surname"),
  custom_info: none,
  student_id: "00000000",
  advisor: "Prof. Name Surname",
  coadvisor: "Name Surname, Name Surname",
  academic_year: [20XX-XX],
  body,
) = {
  // Set page margins
  set page(margin: (top: 2.5cm, x: 2.5cm))

  // Set text default size
  set text(12pt)

  // Set font
  set text(font: "New Computer Modern")

  // Title page
  page(background: place(
    dx: 287.5pt,
    dy: -115pt,
    image("../images/aureole_transparent_40.svg", width: 70%),
  ), {
    place(
      dx: -0.7cm,
      dy: 1.4cm,
      image("../images/logo_with_school_name.svg", width: 70%),
    )

    place(dx: 0cm, dy: 11cm, [
      #text(fill: blue_polimi, size: 24.88pt, weight: "bold", title)
      #v(1cm)
      #text(fill: blue_polimi, size: 14.4pt, weight: "bold", subtitle)
      #v(1cm)
      #text(size: 17.28pt, {
        if type(authors) == array {
          [Authors: *#(authors.join(", "))*]
        } else {
          [Author: *#authors*]
        }
      })
    ])

    align(bottom, {
      if custom_info != none { [Bruh] + linebreak() }
      if student_id != none { [Student ID: #student_id] + linebreak() }
      if advisor != none { [Advisor: #advisor] + linebreak() }
      if coadvisor != none { [Co-advisors: #coadvisor] + linebreak() }
      [Academic Year: #academic_year]
    })
  })

  body
}
