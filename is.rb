require 'benchmark'
#require 'dalli'

#options = { namespace: "is", compress: true }
#cache = Dalli::Client.new('localhost:11211', options)

COUNT = 10000000 # кол-во рабочих

# от сюда ...

class Employee
  attr_accessor :age, :salary, :height, :weight

  def initialize
    @age = rand(100)
    @height = rand(200)
    @weight = rand(200)
    @salary = 0.1 * rand(10000000)
  end
end

@staff = [ ]

#cache.flush

for id in 1 .. COUNT / 10000
#  if (employee = cache.get("employee_#{id}")).nil?
    employee = Employee.new
#    cache.set("employee_#{id}", employee)
#  end

  @staff << employee
end

# ... до сюда, без комментариев.

# Условия поиска для полей экземпляров класса Employee
# (для максимального и(или) минимального значения поля допускается nil)
#if (input = cache.get("input")).nil?
  input = { age:    { min: rand(25),
                      max: 75+rand(25) },
            height: { min: nil,
                      max: 150 + rand(50) },
            weight: { min: rand(50),
                      max: nil },
            salary: { min: 0.1 * rand(2500000),
                      max: 750000 + 0.1 * rand(2500000) } }
#  puts cache.set("input", input)
#end

# Функция поиска в массиве staff, по одному из показателей поля экземпляра класса Employee
def search(array, value, limit, attribute)

  mid = 0
  low = 0
  high = array.length - 1

  # Если условие поиска не отсутсвует.
  if not value.nil?
    # Интерполирующий поиск
    while array[low] <= value and array[high] >= value

      # Если судить по описанию, в найденых мною источников,
      # в эту строку закладывается следующее ...
      # интерполирующий поиск производит оценку новой области поиска
      # по расстоянию между ключом поиска и текущим значением элемента

      mid = low + ( (value-array[low])*(high-low) ) / ( array[high]-array[low] ).round

      # Eсли значение элемента mid меньше, то смещаем нижнюю границу
      if array[mid] < value
        low = mid+1
      # Eсли значение элемента mid больше, то смещаем верхнюю границу
      elsif array[mid] > value
        high = mid-1;
      # Если равны, то ...
      else
        break
      end
    end

    #
    # Следующий участок кода добавлен потому, что любой из поисков,
    # хоть это бинарный или интерполирующий, имеет недостаток, связанный
    # с тем, что идя от центра массива, или предположительного места
    # нахождения искомого значения, поиск завершается, как только дойдёт
    # до этого самого искомого значения, и всё бы было хорошо, если бы не
    # ситуация, когда могут быть дубликаты в отсортированном массиве.

    if limit == :min
      if array[mid] >= value
        while array[mid-1] >= value
          mid -= 1
        end
      else
        while array[mid] < value
          mid += 1
        end
      end
    else
      if array[mid] <= value
        while array[mid+1] <= value
          mid += 1
        end
      else
        while array[mid] > value
          mid -= 1
        end
      end
    end

    # Конец.
    #

  # Если отсутствует минимальное условие
  elsif limit == :min
    mid = low
  # Если отсутствует максимальное условие
  else
    mid = high
  end

  return mid
end

result = [ ]

# Массив потоков
threads = [ ]

puts "Всего экземпляров (всего рабочих) #{COUNT}"

Benchmark.bm { |bench|
  bench.report("Весь поиск") {
    [:age, :height, :weight, :salary].each { |attribute|
      threads << Thread.new {
        # Каждый потока сортирует штат
        # по подотчётному ему атрибуту
        staff = @staff.sort_by{ |e| e.send(attribute) }

        # Массив подпотоков
        subthreads = [ ]

        [:min, :max].each { |limit|
          subthreads << Thread.new {
            # Каждый подпоток ищет границу
            # подотчётного ему предела
            search(staff.map(&attribute), input[attribute][limit], limit, attribute)
          }
        }

        # Заменяем значения массива подпотоков на результаты
        # полученные по завершению их выполнения.
        subthreads.map!{ |thread| thread.value }

        # Каждый поток возвращает массив состоящий только из тех работников,
        # значение параметра которых удовлетворяют условию поиска.
        staff[subthreads[0]..subthreads[1]]
      }
    }

    # Заменив значения массива потоков на результаты полученные по их завершению,
    # и произведя пересечение всех полученных четырёх массивов, вы получаем один
    # результирующий массив, состоящий из только из работников, чьи значения полей
    # удовлетворяет всем условиям поиска.
    result = threads.map!{ |thread| thread.value }.inject(:&)
  }
}


puts 'Кол-во экземпляров (кол-во рабочих)'
puts "соответствующих условиям поиска #{result.size}"

puts ''

puts input.inspect

puts 'Выбранные работники, которых не должно быть по условию поиска'

result.each do |employee|

  unless ( ( input[:age][:min].nil? ? true : employee.age >= input[:age][:min] ) and \
           ( input[:age][:max].nil? ? true : employee.age <= input[:age][:max] ) and \
           ( input[:height][:min].nil? ? true : employee.height >= input[:height][:min] ) and \
           ( input[:height][:max].nil? ? true : employee.height <= input[:height][:max] ) and \
           ( input[:weight][:min].nil? ? true : employee.weight >= input[:weight][:min] ) and \
           ( input[:weight][:max].nil? ? true : employee.weight <= input[:weight][:max] ) and \
           ( input[:salary][:min].nil? ? true : employee.salary >= input[:salary][:min] ) and \
           ( input[:salary][:max].nil? ? true : employee.salary <= input[:salary][:max] ) )

    puts employee.inspect

  end
end

puts 'Остальные работники, которые должны быть в числе выбранных по условию поиска'

(@staff-result).each do |employee|

  if ( ( input[:age][:min].nil? ? true : employee.age >= input[:age][:min] ) and \
       ( input[:age][:max].nil? ? true : employee.age <= input[:age][:max] ) and \
       ( input[:height][:min].nil? ? true : employee.height >= input[:height][:min] ) and \
       ( input[:height][:max].nil? ? true : employee.height <= input[:height][:max] ) and \
       ( input[:weight][:min].nil? ? true : employee.weight >= input[:weight][:min] ) and \
       ( input[:weight][:max].nil? ? true : employee.weight <= input[:weight][:max] ) and \
       ( input[:salary][:min].nil? ? true : employee.salary >= input[:salary][:min] ) and \
       ( input[:salary][:max].nil? ? true : employee.salary <= input[:salary][:max] ) )

    puts employee.inspect

  end
end

# Флэнаган Д., Мацумото Ю., Язык программирования Ruby, 2011, начиная с 446 стр.

# http://ru.wikipedia.org/wiki/%D0%98%D0%BD%D1%82%D0%B5%D1%80%D0%BF%D0%BE%D0%BB%D0%B8%D1%80%D1%83%D1%8E%D1%89%D0%B8%D0%B9_%D0%BF%D0%BE%D0%B8%D1%81%D0%BA
# http://mathhelpplanet.com/static.php?p=javascript-algoritmy-poiska
# http://iguania.ru/algoritmi-programmirovaniya/interpoliruiuschiy-poisk.html

# http://ruby.about.com/od/tasks/f/benchmark.htm